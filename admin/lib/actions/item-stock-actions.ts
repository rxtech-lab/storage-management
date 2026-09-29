"use server";

import { revalidatePath } from "next/cache";
import { and, eq, inArray, isNull, ne, sum, type SQL } from "drizzle-orm";
import type { BatchItem } from "drizzle-orm/batch";
import { nanoid } from "nanoid";
import { z } from "zod";
import {
  db,
  items,
  itemStocks,
  locations,
  positions,
  stockHistories,
  type ItemStock,
} from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";
import { getSession } from "@/lib/auth-helper";
import { getItem, type ItemWithRelations } from "./item-actions";
import { signImagesArrayWithIds } from "./s3-upload-actions";
import {
  validateFileOwnership,
  validateFilesExistInS3,
  associateFilesWithItem,
  disassociateFilesFromItem,
} from "./file-actions";
import { parseFileIds } from "@/lib/utils/file-utils";

const fileIdPattern = /^file:[\w-]+$/;

const moveItemStockSchema = z.object({
  fromStockId: z.string().min(1).nullable().optional(),
  // Omitted means no parent (clients may drop null fields)
  toParentId: z.string().min(1).nullable().optional(),
  quantity: z.number().int().min(1).optional(),
  merge: z.boolean().optional(),
  note: z.string().nullable().optional(),
});

const itemStockUpdateSchema = z.object({
  // Empty string clears the location (clients may drop null fields)
  locationId: z.string().nullable().optional(),
  images: z
    .array(z.string().regex(fileIdPattern, "Images must be in 'file:{id}' format"))
    .optional(),
  note: z.string().nullable().optional(),
  positions: z
    .array(
      z.object({
        positionSchemaId: z.string().min(1),
        data: z.record(z.unknown()),
      }),
    )
    .optional(),
});

export type MoveItemStockInput = z.infer<typeof moveItemStockSchema>;
export type ItemStockUpdateInput = z.infer<typeof itemStockUpdateSchema>;

export interface ItemStockDetail {
  id: string;
  itemId: string;
  parentId: string | null;
  parent: { id: string; title: string } | null;
  locationId: string | null;
  location: { id: string; title: string; latitude: number; longitude: number } | null;
  images: { id: string; url: string }[];
  note: string | null;
  quantity: number;
  positions: { id: string; positionSchemaId: string; data: Record<string, unknown> }[];
  createdAt: Date;
  updatedAt: Date;
}

type Batch = [BatchItem<"sqlite">, ...BatchItem<"sqlite">[]];

async function resolveUserId(userId?: string): Promise<string | undefined> {
  if (userId) return userId;
  const session = await getSession();
  return session?.user?.id;
}

function parentCondition(column: typeof itemStocks.parentId, parentId: string | null): SQL {
  return parentId === null ? isNull(column) : eq(column, parentId);
}

/**
 * Quantities per placement of an item. Units without a stock_id belong to the
 * item's main placement.
 */
async function getPlacementQuantities(itemId: string) {
  const rows = await db
    .select({ stockId: stockHistories.stockId, total: sum(stockHistories.quantity) })
    .from(stockHistories)
    .where(eq(stockHistories.itemId, itemId))
    .groupBy(stockHistories.stockId);

  const byStock = new Map<string, number>();
  let main = 0;
  let total = 0;
  for (const row of rows) {
    const quantity = Number(row.total ?? 0);
    total += quantity;
    if (row.stockId) {
      byStock.set(row.stockId, quantity);
    } else {
      main += quantity;
    }
  }
  return { total, main, byStock };
}

async function buildStockDetails(
  stocks: ItemStock[],
  quantities: Map<string, number>,
): Promise<ItemStockDetail[]> {
  if (stocks.length === 0) return [];

  const parentIds = [...new Set(stocks.map((s) => s.parentId).filter((id): id is string => !!id))];
  const locationIds = [
    ...new Set(stocks.map((s) => s.locationId).filter((id): id is string => !!id)),
  ];
  const stockIds = stocks.map((s) => s.id);

  const [parentRows, locationRows, positionRows] = await Promise.all([
    parentIds.length > 0
      ? db.select({ id: items.id, title: items.title }).from(items).where(inArray(items.id, parentIds))
      : Promise.resolve([]),
    locationIds.length > 0
      ? db
          .select({
            id: locations.id,
            title: locations.title,
            latitude: locations.latitude,
            longitude: locations.longitude,
          })
          .from(locations)
          .where(inArray(locations.id, locationIds))
      : Promise.resolve([]),
    db
      .select({
        id: positions.id,
        stockId: positions.stockId,
        positionSchemaId: positions.positionSchemaId,
        data: positions.data,
      })
      .from(positions)
      .where(inArray(positions.stockId, stockIds)),
  ]);

  const parentById = new Map(parentRows.map((p) => [p.id, p]));
  const locationById = new Map(locationRows.map((l) => [l.id, l]));

  return Promise.all(
    stocks.map(async (stock) => ({
      id: stock.id,
      itemId: stock.itemId,
      parentId: stock.parentId,
      parent: stock.parentId ? (parentById.get(stock.parentId) ?? null) : null,
      locationId: stock.locationId,
      location: stock.locationId ? (locationById.get(stock.locationId) ?? null) : null,
      images:
        stock.images && stock.images.length > 0
          ? await signImagesArrayWithIds(stock.images)
          : [],
      note: stock.note,
      quantity: quantities.get(stock.id) ?? 0,
      positions: positionRows
        .filter((p) => p.stockId === stock.id)
        .map(({ id, positionSchemaId, data }) => ({ id, positionSchemaId, data })),
      createdAt: stock.createdAt,
      updatedAt: stock.updatedAt,
    })),
  );
}

/**
 * Stock placements of an item plus the quantity left in its main placement.
 */
export async function getItemStockPlacements(
  itemId: string,
): Promise<{ stocks: ItemStockDetail[]; mainQuantity: number }> {
  await ensureSchemaInitialized();
  const [stocks, quantities] = await Promise.all([
    db
      .select()
      .from(itemStocks)
      .where(eq(itemStocks.itemId, itemId))
      .orderBy(itemStocks.createdAt),
    getPlacementQuantities(itemId),
  ]);
  return {
    stocks: await buildStockDetails(stocks, quantities.byStock),
    mainQuantity: quantities.main,
  };
}

/**
 * Stock placements of other items that are stored inside the given parent item.
 */
export async function getStoredStocks(
  parentId: string,
): Promise<{ stock: ItemStockDetail; item: ItemWithRelations }[]> {
  await ensureSchemaInitialized();
  const stocks = await db
    .select()
    .from(itemStocks)
    .where(eq(itemStocks.parentId, parentId))
    .orderBy(itemStocks.createdAt);
  if (stocks.length === 0) return [];

  const quantityRows = await db
    .select({ stockId: stockHistories.stockId, total: sum(stockHistories.quantity) })
    .from(stockHistories)
    .where(inArray(stockHistories.stockId, stocks.map((s) => s.id)))
    .groupBy(stockHistories.stockId);
  const quantities = new Map(
    quantityRows.map((row) => [row.stockId as string, Number(row.total ?? 0)]),
  );

  const nonEmpty = stocks.filter((s) => (quantities.get(s.id) ?? 0) > 0);
  const [details, owners] = await Promise.all([
    buildStockDetails(nonEmpty, quantities),
    Promise.all(nonEmpty.map((s) => getItem(s.itemId))),
  ]);

  return details.flatMap((stock, index) => {
    const item = owners[index];
    return item ? [{ stock, item }] : [];
  });
}

/**
 * Queries that fold one placement into another placement, or into the item's
 * main placement when `destination` is null: history rows are re-pointed and
 * the source placement removed. Images carry over only into another placement;
 * the main placement keeps the item's own images.
 */
function foldPlacementQueries(source: ItemStock, destination: ItemStock | null): Batch {
  const queries: Batch = [
    db
      .update(stockHistories)
      .set({ stockId: destination?.id ?? null })
      .where(eq(stockHistories.stockId, source.id)),
    db.delete(positions).where(eq(positions.stockId, source.id)),
    db.delete(itemStocks).where(eq(itemStocks.id, source.id)),
  ];
  if (destination) {
    const destinationImages = destination.images ?? [];
    const mergedImages = [
      ...destinationImages,
      ...(source.images ?? []).filter((img) => !destinationImages.includes(img)),
    ];
    queries.push(
      db
        .update(itemStocks)
        .set({ images: mergedImages, updatedAt: new Date() })
        .where(eq(itemStocks.id, destination.id)),
    );
  }
  return queries;
}

function revalidateItemPaths(...ids: (string | null | undefined)[]) {
  revalidatePath("/items");
  for (const id of ids) {
    if (id) revalidatePath(`/items/${id}`);
  }
}

/**
 * Move some or all units of an item from one placement to a destination parent.
 * A whole placement move re-parents it; a partial move records a -n/+n pair of
 * stock history entries. Placements that end up under the same parent are merged
 * unless `merge` is false.
 */
export async function moveItemStockAction(
  itemId: string,
  input: MoveItemStockInput,
  userId?: string,
): Promise<{
  success: boolean;
  data?: { stockId: string | null; quantity: number };
  error?: string;
}> {
  try {
    await ensureSchemaInitialized();
    const resolvedUserId = await resolveUserId(userId);
    if (!resolvedUserId) {
      return { success: false, error: "Unauthorized" };
    }

    const parsed = moveItemStockSchema.safeParse(input);
    if (!parsed.success) {
      const errors = parsed.error.errors
        .map((e) => `${e.path.join(".")}: ${e.message}`)
        .join(", ");
      return { success: false, error: `Validation failed: ${errors}` };
    }
    const { quantity: requested, note } = parsed.data;
    const toParentId = parsed.data.toParentId ?? null;
    const fromStockId = parsed.data.fromStockId ?? null;
    const merge = parsed.data.merge ?? true;

    const [item] = await db.select().from(items).where(eq(items.id, itemId)).limit(1);
    if (!item || item.userId !== resolvedUserId) {
      return { success: false, error: "Permission denied" };
    }

    if (toParentId === itemId) {
      return { success: false, error: "An item can't be stored inside itself" };
    }

    let parentTitle = "no parent";
    if (toParentId) {
      const [parent] = await db
        .select({ userId: items.userId, title: items.title })
        .from(items)
        .where(eq(items.id, toParentId))
        .limit(1);
      if (!parent || parent.userId !== resolvedUserId) {
        return { success: false, error: "Parent item not found or permission denied" };
      }
      parentTitle = parent.title;
    }

    let source: ItemStock | undefined;
    if (fromStockId) {
      [source] = await db
        .select()
        .from(itemStocks)
        .where(and(eq(itemStocks.id, fromStockId), eq(itemStocks.itemId, itemId)))
        .limit(1);
      if (!source) {
        return { success: false, error: "Stock placement not found" };
      }
    }

    const quantities = await getPlacementQuantities(itemId);
    const sourceQuantity = source ? (quantities.byStock.get(source.id) ?? 0) : quantities.main;
    const sourceParentId = source ? source.parentId : item.parentId;
    const isWhole = requested === undefined || requested >= sourceQuantity;
    const moveQuantity = isWhole ? Math.max(sourceQuantity, 0) : requested;

    if (sourceParentId === toParentId && (merge || isWhole)) {
      // Already there - nothing to move
      return { success: true, data: { stockId: fromStockId, quantity: 0 } };
    }

    const mainIsDestination = merge && item.parentId === toParentId;
    const [existingDestination] =
      merge && !mainIsDestination
        ? await db
            .select()
            .from(itemStocks)
            .where(
              and(
                eq(itemStocks.itemId, itemId),
                parentCondition(itemStocks.parentId, toParentId),
                fromStockId ? ne(itemStocks.id, fromStockId) : undefined,
              ),
            )
            .limit(1)
        : [];

    const now = new Date();
    let destinationStockId: string | null;
    const queries: BatchItem<"sqlite">[] = [];

    if (isWhole && !source) {
      // Main placement moves: re-parent the item itself
      queries.push(
        db.update(items).set({ parentId: toParentId, updatedAt: now }).where(eq(items.id, itemId)),
      );
      if (existingDestination) {
        queries.push(...foldPlacementQueries(existingDestination, null));
      }
      destinationStockId = null;
    } else if (isWhole && source) {
      if (mainIsDestination) {
        queries.push(...foldPlacementQueries(source, null));
        destinationStockId = null;
      } else if (existingDestination) {
        queries.push(...foldPlacementQueries(source, existingDestination));
        destinationStockId = existingDestination.id;
      } else {
        queries.push(
          db
            .update(itemStocks)
            .set({ parentId: toParentId, updatedAt: now })
            .where(eq(itemStocks.id, source.id)),
        );
        destinationStockId = source.id;
      }
    } else {
      // Partial move: split units off into the destination placement
      if (mainIsDestination) {
        destinationStockId = null;
      } else if (existingDestination) {
        destinationStockId = existingDestination.id;
      } else {
        destinationStockId = nanoid();
        queries.push(
          db.insert(itemStocks).values({
            id: destinationStockId,
            userId: resolvedUserId,
            itemId,
            parentId: toParentId,
            locationId: source ? source.locationId : item.locationId,
            images: [],
            createdAt: now,
            updatedAt: now,
          }),
        );
      }

      let sourceTitle = "no parent";
      if (sourceParentId) {
        const [sourceParent] = await db
          .select({ title: items.title })
          .from(items)
          .where(eq(items.id, sourceParentId))
          .limit(1);
        sourceTitle = sourceParent?.title ?? sourceTitle;
      }

      queries.push(
        db.insert(stockHistories).values([
          {
            userId: resolvedUserId,
            itemId,
            stockId: fromStockId,
            quantity: -moveQuantity,
            note: note || `Moved to ${parentTitle}`,
            createdAt: now,
          },
          {
            userId: resolvedUserId,
            itemId,
            stockId: destinationStockId,
            quantity: moveQuantity,
            note: note || `Moved from ${sourceTitle}`,
            createdAt: now,
          },
        ]),
      );
    }

    if (toParentId) {
      queries.push(
        db.update(items).set({ lastUsedAsParent: now }).where(eq(items.id, toParentId)),
      );
    }

    await db.batch(queries as Batch);

    revalidateItemPaths(itemId, sourceParentId, toParentId);
    return { success: true, data: { stockId: destinationStockId, quantity: moveQuantity } };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to move stock",
    };
  }
}

async function getOwnedStock(
  stockId: string,
  userId: string,
): Promise<{ stock?: ItemStock; error?: string }> {
  const [stock] = await db.select().from(itemStocks).where(eq(itemStocks.id, stockId)).limit(1);
  if (!stock) return { error: "Stock placement not found" };
  if (stock.userId !== userId) return { error: "Permission denied" };
  return { stock };
}

export async function getItemStock(stockId: string): Promise<ItemStockDetail | undefined> {
  await ensureSchemaInitialized();
  const [stock] = await db.select().from(itemStocks).where(eq(itemStocks.id, stockId)).limit(1);
  if (!stock) return undefined;
  const quantities = await getPlacementQuantities(stock.itemId);
  const [detail] = await buildStockDetails([stock], quantities.byStock);
  return detail;
}

/**
 * Update a placement's location, images, note, and (replace) positions.
 */
export async function updateItemStockAction(
  stockId: string,
  data: ItemStockUpdateInput,
  userId?: string,
): Promise<{ success: boolean; data?: ItemStockDetail; error?: string }> {
  try {
    await ensureSchemaInitialized();
    const resolvedUserId = await resolveUserId(userId);
    if (!resolvedUserId) {
      return { success: false, error: "Unauthorized" };
    }

    const parsed = itemStockUpdateSchema.safeParse(data);
    if (!parsed.success) {
      const errors = parsed.error.errors
        .map((e) => `${e.path.join(".")}: ${e.message}`)
        .join(", ");
      return { success: false, error: `Validation failed: ${errors}` };
    }
    const input = parsed.data;

    const { stock, error } = await getOwnedStock(stockId, resolvedUserId);
    if (!stock) {
      return { success: false, error };
    }

    if (input.locationId) {
      const [location] = await db
        .select({ userId: locations.userId })
        .from(locations)
        .where(eq(locations.id, input.locationId))
        .limit(1);
      if (!location || location.userId !== resolvedUserId) {
        return { success: false, error: "Location not found or permission denied" };
      }
    }

    if (input.images !== undefined) {
      const oldFileIds = parseFileIds(stock.images ?? []);
      const newFileIds = parseFileIds(input.images);
      const addedFileIds = newFileIds.filter((id) => !oldFileIds.includes(id));
      const removedFileIds = oldFileIds.filter((id) => !newFileIds.includes(id));

      if (addedFileIds.length > 0) {
        const ownership = await validateFileOwnership(addedFileIds, resolvedUserId);
        if (!ownership.valid) {
          return { success: false, error: ownership.error };
        }
        const s3Result = await validateFilesExistInS3(addedFileIds);
        if (!s3Result.valid) {
          return { success: false, error: s3Result.error };
        }
        // Files belong to the item so they are cleaned up with it
        await associateFilesWithItem(addedFileIds, stock.itemId, resolvedUserId);
      }
      if (removedFileIds.length > 0) {
        await disassociateFilesFromItem(removedFileIds);
      }
    }

    const now = new Date();
    const queries: Batch = [
      db
        .update(itemStocks)
        .set({
          ...(input.locationId !== undefined && { locationId: input.locationId || null }),
          ...(input.images !== undefined && { images: input.images }),
          ...(input.note !== undefined && { note: input.note || null }),
          updatedAt: now,
        })
        .where(eq(itemStocks.id, stockId)),
    ];

    if (input.positions !== undefined) {
      queries.push(db.delete(positions).where(eq(positions.stockId, stockId)));
      if (input.positions.length > 0) {
        queries.push(
          db.insert(positions).values(
            input.positions.map((pos) => ({
              userId: resolvedUserId,
              itemId: stock.itemId,
              stockId,
              positionSchemaId: pos.positionSchemaId,
              data: pos.data,
              createdAt: now,
              updatedAt: now,
            })),
          ),
        );
      }
    }

    await db.batch(queries);

    revalidateItemPaths(stock.itemId, stock.parentId);
    return { success: true, data: await getItemStock(stockId) };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to update stock placement",
    };
  }
}

/**
 * Remove a placement, returning its units to the item's main placement.
 */
export async function deleteItemStockAction(
  stockId: string,
  userId?: string,
): Promise<{ success: boolean; error?: string }> {
  try {
    await ensureSchemaInitialized();
    const resolvedUserId = await resolveUserId(userId);
    if (!resolvedUserId) {
      return { success: false, error: "Unauthorized" };
    }

    const { stock, error } = await getOwnedStock(stockId, resolvedUserId);
    if (!stock) {
      return { success: false, error };
    }

    await db.batch(foldPlacementQueries(stock, null));

    revalidateItemPaths(stock.itemId, stock.parentId);
    return { success: true };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to delete stock placement",
    };
  }
}
