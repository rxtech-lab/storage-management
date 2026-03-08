"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { eq, like, or, desc, asc, isNull, and, ne, lt, gt, gte, lte, sql, inArray, count } from "drizzle-orm";
import { z } from "zod";
import {
  db,
  items,
  categories,
  locations,
  authors,
  positions,
  itemTags,
  type Item,
  type NewItem,
} from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";
import { getSession } from "@/lib/auth-helper";
import {
  validateFileOwnership,
  validateFilesExistInS3,
  associateFilesWithItem,
  disassociateFilesFromItem,
  deleteFilesForItem,
} from "./file-actions";
import { parseFileIds } from "@/lib/utils/file-utils";
import {
  type PaginationParams,
  type PaginatedResult,
  decodeCursor,
  buildPaginatedResponse,
  DEFAULT_PAGE_SIZE,
} from "@/lib/utils/pagination";

// Zod schema for position data
const positionDataSchema = z.object({
  positionSchemaId: z.string().min(1),
  data: z.record(z.unknown()),
});

// Regex pattern for file:{id} format
const fileIdPattern = /^file:[\w-]+$/;

// Zod schema for item validation
const itemInsertSchema = z.object({
  title: z.string().min(1, "Title is required"),
  description: z.string().nullable().optional(),
  originalQrCode: z.string().nullable().optional(),
  categoryId: z.string().min(1).nullable().optional(),
  locationId: z.string().min(1).nullable().optional(),
  authorId: z.string().min(1).nullable().optional(),
  parentId: z.string().min(1).nullable().optional(),
  price: z.number().nullable().optional(),
  currency: z.string().optional(),
  visibility: z.enum(["publicAccess", "privateAccess"]),
  itemDate: z.coerce.date().nullable().optional(),
  expiresAt: z.coerce.date().nullable().optional(),
  images: z
    .array(
      z.string().regex(fileIdPattern, "Images must be in 'file:{id}' format"),
    )
    .optional(),
  positions: z.array(positionDataSchema).optional(),
});

const itemUpdateSchema = itemInsertSchema
  .partial()
  .omit({ visibility: true })
  .extend({
    visibility: z.enum(["publicAccess", "privateAccess"]).optional(),
  });

export interface ItemWithRelations extends Item {
  category?: { id: string; name: string; description: string | null } | null;
  location?: {
    id: string;
    title: string;
    latitude: number | null;
    longitude: number | null;
  } | null;
  author?: { id: string; name: string; bio: string | null } | null;
  parent?: { id: string; title: string } | null;
}

export type ComparisonOp = "gt" | "gte" | "lt" | "lte" | "eq";

export interface ItemFilters {
  userId?: string;
  categoryId?: string;
  locationId?: string;
  authorId?: string;
  parentId?: string | null; // null means get root items (no parent)
  visibility?: "publicAccess" | "privateAccess";
  search?: string;
  sortBy?: "createdAt" | "lastUsedAsParent";
  tagIds?: string[];
  itemDateOp?: ComparisonOp;
  itemDateValue?: string;
  expiresAtOp?: ComparisonOp;
  expiresAtValue?: string;
}

export interface PaginatedItemFilters extends ItemFilters, PaginationParams {}

export async function getItems(
  userId?: string,
  filters?: ItemFilters,
): Promise<ItemWithRelations[]> {
  await ensureSchemaInitialized();

  // Use explicitly passed userId first, fall back to session
  const session = !userId ? await getSession() : null;
  const sessionUserId = userId ?? session?.user?.id;
  if (!sessionUserId) {
    return [];
  }

  let query = db
    .select({
      id: items.id,
      userId: items.userId,
      title: items.title,
      description: items.description,
      originalQrCode: items.originalQrCode,
      categoryId: items.categoryId,
      locationId: items.locationId,
      authorId: items.authorId,
      parentId: items.parentId,
      price: items.price,
      currency: items.currency,
      visibility: items.visibility,
      images: items.images,
      createdAt: items.createdAt,
      updatedAt: items.updatedAt,
      lastUsedAsParent: items.lastUsedAsParent,
      itemDate: items.itemDate,
      expiresAt: items.expiresAt,
      category: {
        id: categories.id,
        name: categories.name,
        description: categories.description,
      },
      location: {
        id: locations.id,
        title: locations.title,
        latitude: locations.latitude,
        longitude: locations.longitude,
      },
      author: {
        id: authors.id,
        name: authors.name,
        bio: authors.bio,
      },
    })
    .from(items)
    .leftJoin(categories, eq(items.categoryId, categories.id))
    .leftJoin(locations, eq(items.locationId, locations.id))
    .leftJoin(authors, eq(items.authorId, authors.id))
    .orderBy(desc(items.updatedAt))
    .$dynamic();

  // Show user's own items OR public items from other users
  const conditions = [
    or(eq(items.userId, sessionUserId), eq(items.visibility, "publicAccess")),
  ];

  if (filters?.categoryId) {
    conditions.push(eq(items.categoryId, filters.categoryId));
  }
  if (filters?.locationId) {
    conditions.push(eq(items.locationId, filters.locationId));
  }
  if (filters?.authorId) {
    conditions.push(eq(items.authorId, filters.authorId));
  }
  if (filters?.parentId !== undefined) {
    if (filters.parentId === null) {
      conditions.push(isNull(items.parentId));
    } else {
      conditions.push(eq(items.parentId, filters.parentId));
    }
  }
  if (filters?.visibility) {
    conditions.push(eq(items.visibility, filters.visibility));
  }
  if (filters?.search) {
    const searchCondition = or(
      like(items.title, `%${filters.search}%`),
      like(items.description, `%${filters.search}%`),
    );
    if (searchCondition) {
      conditions.push(searchCondition);
    }
  }

  if (conditions.length > 0) {
    query = query.where(and(...conditions));
  }

  const results = await query;

  return results.map((row) => ({
    ...row,
    category: row.category?.id ? row.category : null,
    location: row.location?.id ? row.location : null,
    author: row.author?.id ? row.author : null,
  }));
}

export async function getItem(
  id: string,
): Promise<ItemWithRelations | undefined> {
  await ensureSchemaInitialized();
  const results = await db
    .select({
      id: items.id,
      userId: items.userId,
      title: items.title,
      description: items.description,
      originalQrCode: items.originalQrCode,
      categoryId: items.categoryId,
      locationId: items.locationId,
      authorId: items.authorId,
      parentId: items.parentId,
      price: items.price,
      currency: items.currency,
      visibility: items.visibility,
      images: items.images,
      createdAt: items.createdAt,
      updatedAt: items.updatedAt,
      lastUsedAsParent: items.lastUsedAsParent,
      itemDate: items.itemDate,
      expiresAt: items.expiresAt,
      category: {
        id: categories.id,
        name: categories.name,
        description: categories.description,
      },
      location: {
        id: locations.id,
        title: locations.title,
        latitude: locations.latitude,
        longitude: locations.longitude,
      },
      author: {
        id: authors.id,
        name: authors.name,
        bio: authors.bio,
      },
    })
    .from(items)
    .leftJoin(categories, eq(items.categoryId, categories.id))
    .leftJoin(locations, eq(items.locationId, locations.id))
    .leftJoin(authors, eq(items.authorId, authors.id))
    .where(eq(items.id, id))
    .limit(1);

  if (!results[0]) return undefined;

  const row = results[0];
  return {
    ...row,
    category: row.category?.id ? row.category : null,
    location: row.location?.id ? row.location : null,
    author: row.author?.id ? row.author : null,
  };
}

export async function getItemChildren(
  parentId: string,
  userId?: string,
  limit?: number,
): Promise<ItemWithRelations[]> {
  const results = await getItems(userId, { parentId });
  if (limit && results.length > limit) {
    return results.slice(0, limit);
  }
  return results;
}

export async function getItemChildrenCount(
  parentId: string,
): Promise<number> {
  await ensureSchemaInitialized();
  const result = await db
    .select({ count: count() })
    .from(items)
    .where(eq(items.parentId, parentId));
  return result[0]?.count ?? 0;
}

/**
 * Find an item by its originalQrCode field
 * @param qrCode The raw QR code value to search for
 * @returns The item if found, null otherwise
 */
export async function findItemByOriginalQrCode(
  qrCode: string,
): Promise<Item | null> {
  await ensureSchemaInitialized();
  const result = await db
    .select()
    .from(items)
    .where(eq(items.originalQrCode, qrCode))
    .limit(1);
  return result[0] || null;
}

export async function createItemAction(
  data: Omit<NewItem, "id" | "userId" | "createdAt" | "updatedAt">,
  userId?: string,
): Promise<{ success: boolean; data?: Item; error?: string }> {
  try {
    await ensureSchemaInitialized();

    // Get userId from session if not provided
    let resolvedUserId = userId;
    if (!resolvedUserId) {
      console.log("Fetching session for userId");
      const session = await getSession();
      if (!session?.user?.id) {
        return { success: false, error: "Unauthorized" };
      }
      resolvedUserId = session.user.id;
    }

    // Validate data with Zod schema
    const validationResult = itemInsertSchema.safeParse(data);
    if (!validationResult.success) {
      const errors = validationResult.error.errors
        .map((e) => `${e.path.join(".")}: ${e.message}`)
        .join(", ");
      return {
        success: false,
        error: `Validation failed: ${errors}`,
      };
    }

    const validatedData = validationResult.data;

    // Check for duplicate item title for this user
    const existingItem = await db
      .select({ id: items.id })
      .from(items)
      .where(
        and(
          eq(items.userId, resolvedUserId),
          eq(items.title, validatedData.title),
        ),
      )
      .limit(1);
    if (existingItem[0]) {
      return {
        success: false,
        error: "An item with this title already exists",
      };
    }

    const images = validatedData.images || [];

    // Validate file IDs if present
    const fileIds = parseFileIds(images);
    if (fileIds.length > 0) {
      // Validate ownership
      const ownershipResult = await validateFileOwnership(
        fileIds,
        resolvedUserId,
      );
      if (!ownershipResult.valid) {
        return { success: false, error: ownershipResult.error };
      }

      // Verify files exist in S3
      const s3Result = await validateFilesExistInS3(fileIds);
      if (!s3Result.valid) {
        return { success: false, error: s3Result.error };
      }
    }

    const now = new Date();

    // Build insert data explicitly, converting empty strings to null
    const insertData = {
      userId: resolvedUserId,
      title: validatedData.title,
      description: validatedData.description || null,
      originalQrCode: validatedData.originalQrCode || null,
      categoryId: validatedData.categoryId || null,
      locationId: validatedData.locationId || null,
      authorId: validatedData.authorId || null,
      parentId: validatedData.parentId || null,
      price: validatedData.price ?? null,
      currency: validatedData.currency || "USD",
      visibility: validatedData.visibility,
      itemDate: validatedData.itemDate ?? null,
      expiresAt: validatedData.expiresAt ?? null,
      images,
      createdAt: now,
      updatedAt: now,
    };

    // Validate parent ownership if parentId is set
    if (insertData.parentId) {
      const parent = await db
        .select({ userId: items.userId })
        .from(items)
        .where(eq(items.id, insertData.parentId))
        .limit(1);
      if (!parent[0] || parent[0].userId !== resolvedUserId) {
        return { success: false, error: "Parent item not found or not owned by user" };
      }
    }

    const result = await db.insert(items).values(insertData).returning();

    // Associate files with the created item
    if (fileIds.length > 0) {
      await associateFilesWithItem(fileIds, result[0].id, resolvedUserId);
    }

    // Create positions if provided
    const positionsData = validatedData.positions || [];
    if (positionsData.length > 0) {
      const now = new Date();
      for (const pos of positionsData) {
        await db.insert(positions).values({
          userId: resolvedUserId,
          itemId: result[0].id,
          positionSchemaId: pos.positionSchemaId,
          data: pos.data as Record<string, unknown>,
          createdAt: now,
          updatedAt: now,
        });
      }
    }

    // Update parent's lastUsedAsParent timestamp
    if (insertData.parentId) {
      await db
        .update(items)
        .set({ lastUsedAsParent: now })
        .where(eq(items.id, insertData.parentId));
    }

    revalidatePath("/items");

    // Fetch the full item with relations for the response
    const createdItem = await getItem(result[0].id);
    if (!createdItem) {
      return { success: false, error: "Item not found after creation" };
    }
    return { success: true, data: createdItem };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to create item",
    };
  }
}

export async function updateItemAction(
  id: string,
  data: Partial<Omit<NewItem, "id" | "userId" | "createdAt" | "updatedAt">>,
  userId?: string,
): Promise<{ success: boolean; data?: Item; error?: string }> {
  try {
    await ensureSchemaInitialized();

    // Validate input data through schema (coerces date strings to Date objects)
    const validationResult = itemUpdateSchema.safeParse(data);
    if (!validationResult.success) {
      const errors = validationResult.error.errors
        .map((e) => `${e.path.join(".")}: ${e.message}`)
        .join(", ");
      return { success: false, error: `Validation failed: ${errors}` };
    }
    data = validationResult.data;

    // Get userId from session if not provided
    let resolvedUserId = userId;
    if (!resolvedUserId) {
      const session = await getSession();
      if (!session?.user?.id) {
        return { success: false, error: "Unauthorized" };
      }
      resolvedUserId = session.user.id;
    }

    // Verify ownership and get current item
    const existing = await db
      .select({ userId: items.userId, images: items.images })
      .from(items)
      .where(eq(items.id, id))
      .limit(1);

    if (!existing[0] || existing[0].userId !== resolvedUserId) {
      return { success: false, error: "Permission denied" };
    }

    // Check for duplicate item title for this user (if title is being updated)
    if (data.title) {
      const duplicateItem = await db
        .select({ id: items.id })
        .from(items)
        .where(
          and(
            eq(items.userId, resolvedUserId),
            eq(items.title, data.title),
            ne(items.id, id),
          ),
        )
        .limit(1);
      if (duplicateItem[0]) {
        return {
          success: false,
          error: "An item with this title already exists",
        };
      }
    }

    // Handle image file ID changes if images are being updated
    if (data.images !== undefined) {
      const newImages = data.images || [];
      const oldImages = existing[0].images || [];

      const newFileIds = parseFileIds(newImages);
      const oldFileIds = parseFileIds(oldImages);

      // Find file IDs that are being added
      const addedFileIds = newFileIds.filter((id) => !oldFileIds.includes(id));
      // Find file IDs that are being removed
      const removedFileIds = oldFileIds.filter(
        (id) => !newFileIds.includes(id),
      );

      // Validate new file IDs
      if (addedFileIds.length > 0) {
        // Validate ownership
        const ownershipResult = await validateFileOwnership(
          addedFileIds,
          resolvedUserId,
        );
        if (!ownershipResult.valid) {
          return { success: false, error: ownershipResult.error };
        }

        // Verify files exist in S3
        const s3Result = await validateFilesExistInS3(addedFileIds);
        if (!s3Result.valid) {
          return { success: false, error: s3Result.error };
        }

        // Associate new files with item
        await associateFilesWithItem(addedFileIds, id, resolvedUserId);
      }

      // Disassociate removed files from item
      if (removedFileIds.length > 0) {
        await disassociateFilesFromItem(removedFileIds);
      }
    }

    // Extract positions from data before updating item
    const { positions: positionsData, ...itemData } = data as typeof data & {
      positions?: Array<{
        positionSchemaId: string;
        data: Record<string, unknown>;
      }>;
    };

    const now = new Date();

    await db
      .update(items)
      .set({ ...itemData, updatedAt: now })
      .where(eq(items.id, id));

    // Update parent's lastUsedAsParent timestamp if parentId is set
    if (itemData.parentId) {
      await db
        .update(items)
        .set({ lastUsedAsParent: now })
        .where(eq(items.id, itemData.parentId));
    }

    // Create new positions if provided
    if (positionsData && positionsData.length > 0) {
      for (const pos of positionsData) {
        await db.insert(positions).values({
          userId: resolvedUserId,
          itemId: id,
          positionSchemaId: pos.positionSchemaId,
          data: pos.data,
          createdAt: now,
          updatedAt: now,
        });
      }
    }

    revalidatePath("/items");
    revalidatePath(`/items/${id}`);

    // Fetch the full item with relations for the response
    const updatedItem = await getItem(id);
    if (!updatedItem) {
      return { success: false, error: "Item not found after update" };
    }
    return { success: true, data: updatedItem };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to update item",
    };
  }
}

export async function deleteItemAction(
  id: string,
  userId?: string,
): Promise<{ success: boolean; error?: string }> {
  try {
    await ensureSchemaInitialized();

    // Get userId from session if not provided
    let resolvedUserId = userId;
    if (!resolvedUserId) {
      const session = await getSession();
      if (!session?.user?.id) {
        return { success: false, error: "Unauthorized" };
      }
      resolvedUserId = session.user.id;
    }

    // Verify ownership
    const existing = await db
      .select({ userId: items.userId })
      .from(items)
      .where(eq(items.id, id))
      .limit(1);

    if (!existing[0]) {
      return { success: false, error: "Item not found" };
    }

    if (!existing[0] || existing[0].userId !== resolvedUserId) {
      return { success: false, error: "Permission denied" };
    }

    // Delete associated files from S3 and database
    // Note: The database cascade will set itemId to null on uploadFiles,
    // but we want to actually delete the files
    await deleteFilesForItem(id);

    await db.delete(items).where(eq(items.id, id));
    revalidatePath("/items");
    return { success: true };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to delete item",
    };
  }
}

export async function createItemAndRedirect(
  data: Omit<NewItem, "id" | "userId" | "createdAt" | "updatedAt">,
  userId?: string,
) {
  const result = await createItemAction(data, userId);
  if (result.success && result.data) {
    redirect(`/items/${result.data.id}`);
  }
  return result;
}

export async function deleteItemAndRedirect(id: string, userId?: string) {
  const result = await deleteItemAction(id, userId);
  if (result.success) {
    redirect("/items");
  }
  return result;
}

export async function deleteItemFormAction(
  id: string,
  userId?: string,
): Promise<void> {
  await deleteItemAction(id, userId);
  redirect("/items");
}

export async function setItemParent(
  childId: string,
  parentId: string | null,
  userId?: string,
): Promise<{ success: boolean; data?: Item; error?: string }> {
  try {
    await ensureSchemaInitialized();

    // Get userId from session if not provided
    let resolvedUserId = userId;
    if (!resolvedUserId) {
      const session = await getSession();
      if (!session?.user?.id) {
        return { success: false, error: "Unauthorized" };
      }
      resolvedUserId = session.user.id;
    }

    // Verify ownership of the child item
    const existing = await db
      .select({ userId: items.userId })
      .from(items)
      .where(eq(items.id, childId))
      .limit(1);

    if (!existing[0] || existing[0].userId !== resolvedUserId) {
      return { success: false, error: "Permission denied" };
    }

    // If parentId is provided, verify the parent exists and belongs to the user
    if (parentId !== null) {
      const parent = await db
        .select({ userId: items.userId })
        .from(items)
        .where(eq(items.id, parentId))
        .limit(1);

      if (!parent[0] || parent[0].userId !== resolvedUserId) {
        return {
          success: false,
          error: "Parent item not found or permission denied",
        };
      }
    }

    // Update only the parentId
    const now = new Date();
    const result = await db
      .update(items)
      .set({ parentId, updatedAt: now })
      .where(eq(items.id, childId))
      .returning();

    // Update parent's lastUsedAsParent timestamp
    if (parentId) {
      await db
        .update(items)
        .set({ lastUsedAsParent: now })
        .where(eq(items.id, parentId));
    }

    revalidatePath("/items");
    revalidatePath(`/items/${childId}`);
    if (parentId) {
      revalidatePath(`/items/${parentId}`);
    }

    return { success: true, data: result[0] };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to update parent",
    };
  }
}

export async function searchItems(
  query: string,
  userId?: string,
  excludeId?: string,
  limit: number = 20,
  sortBy?: "createdAt" | "lastUsedAsParent",
): Promise<{ id: string; title: string }[]> {
  // Get userId from session if not provided
  let resolvedUserId = userId;
  if (!resolvedUserId) {
    const session = await getSession();
    resolvedUserId = session?.user?.id;
  }

  const conditions = [];

  // Filter by userId: show user's own items OR public items
  if (resolvedUserId) {
    conditions.push(
      or(
        eq(items.userId, resolvedUserId),
        eq(items.visibility, "publicAccess"),
      ),
    );
  } else {
    // No user - only show public items
    conditions.push(eq(items.visibility, "publicAccess"));
  }

  if (query) {
    conditions.push(
      or(
        like(items.title, `%${query}%`),
        like(items.description, `%${query}%`),
      ),
    );
  }

  if (excludeId) {
    conditions.push(ne(items.id, excludeId));
  }

  const orderByClause = sortBy === "lastUsedAsParent"
    ? [
        sql`CASE WHEN ${items.lastUsedAsParent} IS NULL THEN 1 ELSE 0 END`,
        desc(items.lastUsedAsParent),
        desc(items.id),
      ]
    : [desc(items.updatedAt)];

  const results = await db
    .select({
      id: items.id,
      title: items.title,
    })
    .from(items)
    .where(conditions.length > 0 ? and(...conditions) : undefined)
    .orderBy(...orderByClause)
    .limit(limit);

  return results;
}

function applyDateComparison(column: typeof items.itemDate | typeof items.expiresAt, op: ComparisonOp, value: Date) {
  switch (op) {
    case "gt": return gt(column, value);
    case "gte": return gte(column, value);
    case "lt": return lt(column, value);
    case "lte": return lte(column, value);
    case "eq": return eq(column, value);
  }
}

export async function getItemsPaginated(
  userId?: string,
  filters?: PaginatedItemFilters,
): Promise<PaginatedResult<ItemWithRelations>> {
  await ensureSchemaInitialized();

  // Prefer explicitly passed userId (from authenticated route handlers) over session
  // This ensures E2E tests work correctly with X-Test-User-Id headers
  const session = await getSession();
  const sessionUserId = userId ?? session?.user?.id;
  if (!sessionUserId) {
    return {
      data: [],
      pagination: {
        nextCursor: null,
        prevCursor: null,
        hasNextPage: false,
        hasPrevPage: false,
        totalCount: 0,
      },
    };
  }

  const limit = filters?.limit ?? DEFAULT_PAGE_SIZE;
  const direction = filters?.direction ?? "next";
  const cursor = filters?.cursor ? decodeCursor(filters.cursor) : null;

  // Build base conditions (same as getItems)
  const conditions = [eq(items.userId, sessionUserId)];

  if (filters?.categoryId) {
    conditions.push(eq(items.categoryId, filters.categoryId));
  }
  if (filters?.locationId) {
    conditions.push(eq(items.locationId, filters.locationId));
  }
  if (filters?.authorId) {
    conditions.push(eq(items.authorId, filters.authorId));
  }
  if (filters?.parentId !== undefined) {
    if (filters.parentId === null) {
      conditions.push(isNull(items.parentId));
    } else {
      conditions.push(eq(items.parentId, filters.parentId));
    }
  }
  if (filters?.visibility) {
    conditions.push(eq(items.visibility, filters.visibility));
  }
  if (filters?.search) {
    const searchCondition = or(
      like(items.title, `%${filters.search}%`),
      like(items.description, `%${filters.search}%`),
    );
    if (searchCondition) {
      conditions.push(searchCondition);
    }
  }

  // Date comparison filters
  if (filters?.itemDateOp && filters?.itemDateValue) {
    const dateValue = new Date(filters.itemDateValue);
    conditions.push(applyDateComparison(items.itemDate, filters.itemDateOp, dateValue));
  }
  if (filters?.expiresAtOp && filters?.expiresAtValue) {
    const dateValue = new Date(filters.expiresAtValue);
    conditions.push(applyDateComparison(items.expiresAt, filters.expiresAtOp, dateValue));
  }

  // Tag filtering (AND logic): items must have ALL specified tags
  const filterByTags = filters?.tagIds && filters.tagIds.length > 0;
  let tagMatchingItemIds: string[] | undefined;
  if (filterByTags) {
    const tagResults = await db
      .select({ itemId: itemTags.itemId })
      .from(itemTags)
      .where(inArray(itemTags.tagId, filters.tagIds!))
      .groupBy(itemTags.itemId)
      .having(sql`count(distinct ${itemTags.tagId}) = ${filters.tagIds!.length}`);
    tagMatchingItemIds = tagResults.map((r) => r.itemId);
    if (tagMatchingItemIds.length === 0) {
      return {
        data: [],
        pagination: {
          nextCursor: null,
          prevCursor: null,
          hasNextPage: false,
          hasPrevPage: false,
          totalCount: 0,
        },
      };
    }
    conditions.push(inArray(items.id, tagMatchingItemIds));
  }

  const sortByLastUsed = filters?.sortBy === "lastUsedAsParent";

  // Capture base conditions length before cursor conditions are added (for count query)
  const baseConditionsLength = conditions.length;

  // Add cursor conditions for pagination
  if (cursor) {
    const cursorId = cursor.id;

    if (sortByLastUsed) {
      // For lastUsedAsParent sort: cursor sortValue may be "" for null timestamps
      const cursorHasValue = cursor.sortValue !== "";
      const cursorTimestamp = cursorHasValue ? new Date(cursor.sortValue) : null;

      if (direction === "next") {
        // NULLS LAST ordering: items with timestamps come first (DESC), then nulls
        if (cursorTimestamp) {
          // Cursor has a timestamp: get items with smaller timestamp, OR same timestamp and smaller id, OR null timestamp
          const cursorCondition = or(
            and(isNull(items.lastUsedAsParent)),
            lt(items.lastUsedAsParent, cursorTimestamp),
            and(eq(items.lastUsedAsParent, cursorTimestamp), lt(items.id, cursorId)),
          );
          if (cursorCondition) conditions.push(cursorCondition);
        } else {
          // Cursor is in the null section: only get nulls with smaller id
          conditions.push(
            and(isNull(items.lastUsedAsParent), lt(items.id, cursorId))!,
          );
        }
      } else {
        if (cursorTimestamp) {
          const cursorCondition = or(
            gt(items.lastUsedAsParent, cursorTimestamp),
            and(eq(items.lastUsedAsParent, cursorTimestamp), gt(items.id, cursorId)),
          );
          if (cursorCondition) conditions.push(cursorCondition);
        } else {
          // Cursor is in the null section: get nulls with larger id, or any with timestamp
          const cursorCondition = or(
            sql`${items.lastUsedAsParent} IS NOT NULL`,
            and(isNull(items.lastUsedAsParent), gt(items.id, cursorId)),
          );
          if (cursorCondition) conditions.push(cursorCondition);
        }
      }
    } else {
      const cursorDate = new Date(cursor.sortValue);

      if (direction === "next") {
        const cursorCondition = or(
          lt(items.createdAt, cursorDate),
          and(eq(items.createdAt, cursorDate), lt(items.id, cursorId)),
        );
        if (cursorCondition) conditions.push(cursorCondition);
      } else {
        const cursorCondition = or(
          gt(items.createdAt, cursorDate),
          and(eq(items.createdAt, cursorDate), gt(items.id, cursorId)),
        );
        if (cursorCondition) conditions.push(cursorCondition);
      }
    }
  }

  // Build query with appropriate order
  let query = db
    .select({
      id: items.id,
      userId: items.userId,
      title: items.title,
      description: items.description,
      originalQrCode: items.originalQrCode,
      categoryId: items.categoryId,
      locationId: items.locationId,
      authorId: items.authorId,
      parentId: items.parentId,
      price: items.price,
      currency: items.currency,
      visibility: items.visibility,
      images: items.images,
      createdAt: items.createdAt,
      updatedAt: items.updatedAt,
      lastUsedAsParent: items.lastUsedAsParent,
      itemDate: items.itemDate,
      expiresAt: items.expiresAt,
      category: {
        id: categories.id,
        name: categories.name,
        description: categories.description,
      },
      location: {
        id: locations.id,
        title: locations.title,
        latitude: locations.latitude,
        longitude: locations.longitude,
      },
      author: {
        id: authors.id,
        name: authors.name,
        bio: authors.bio,
      },
    })
    .from(items)
    .leftJoin(categories, eq(items.categoryId, categories.id))
    .leftJoin(locations, eq(items.locationId, locations.id))
    .leftJoin(authors, eq(items.authorId, authors.id))
    .$dynamic();

  if (conditions.length > 0) {
    query = query.where(and(...conditions));
  }

  // Order depends on direction and sort field
  if (sortByLastUsed) {
    // NULLS LAST: items with lastUsedAsParent come first (DESC), then nulls sorted by id DESC
    if (direction === "next") {
      query = query.orderBy(
        sql`CASE WHEN ${items.lastUsedAsParent} IS NULL THEN 1 ELSE 0 END`,
        desc(items.lastUsedAsParent),
        desc(items.id),
      );
    } else {
      query = query.orderBy(
        sql`CASE WHEN ${items.lastUsedAsParent} IS NULL THEN 0 ELSE 1 END`,
        asc(items.lastUsedAsParent),
        asc(items.id),
      );
    }
  } else {
    if (direction === "next") {
      query = query.orderBy(desc(items.createdAt), desc(items.id));
    } else {
      query = query.orderBy(asc(items.createdAt), asc(items.id));
    }
  }

  // Fetch one extra to determine if there are more items
  query = query.limit(limit + 1);

  // Run data query and count query in parallel
  // Count query uses only base conditions (without cursor pagination conditions)
  const baseConditions = conditions.slice(0, baseConditionsLength);
  const [results, countResult] = await Promise.all([
    query,
    db.select({ count: count() }).from(items).where(and(...baseConditions)),
  ]);
  const totalCount = countResult[0]?.count ?? 0;

  // Map results to proper format
  const mappedResults = results.map((row) => ({
    ...row,
    category: row.category?.id ? row.category : null,
    location: row.location?.id ? row.location : null,
    author: row.author?.id ? row.author : null,
  }));

  // Build paginated response
  return buildPaginatedResponse(
    mappedResults,
    limit,
    direction,
    (item) =>
      sortByLastUsed
        ? (item.lastUsedAsParent?.toISOString() ?? "")
        : item.createdAt.toISOString(),
    !!cursor,
    totalCount,
  );
}
