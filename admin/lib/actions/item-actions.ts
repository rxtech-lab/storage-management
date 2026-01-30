"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { eq, like, or, desc, isNull, and, ne } from "drizzle-orm";
import { z } from "zod";
import {
  db,
  items,
  categories,
  locations,
  authors,
  positions,
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

// Zod schema for position data
const positionDataSchema = z.object({
  positionSchemaId: z.number().int().positive(),
  data: z.record(z.unknown()),
});

// Zod schema for item validation
const itemInsertSchema = z.object({
  title: z.string().min(1, "Title is required"),
  description: z.string().nullable().optional(),
  originalQrCode: z.string().nullable().optional(),
  categoryId: z.number().int().positive().nullable().optional(),
  locationId: z.number().int().positive().nullable().optional(),
  authorId: z.number().int().positive().nullable().optional(),
  parentId: z.number().int().positive().nullable().optional(),
  price: z.number().nullable().optional(),
  currency: z.string().optional(),
  visibility: z.enum(["public", "private"]),
  images: z.array(z.string()).optional(),
  positions: z.array(positionDataSchema).optional(),
});

const itemUpdateSchema = itemInsertSchema
  .partial()
  .omit({ visibility: true })
  .extend({
    visibility: z.enum(["public", "private"]).optional(),
  });

export interface ItemWithRelations extends Item {
  category?: { id: number; name: string } | null;
  location?: { id: number; title: string } | null;
  author?: { id: number; name: string } | null;
  parent?: { id: number; title: string } | null;
}

export interface ItemFilters {
  userId?: string;
  categoryId?: number;
  locationId?: number;
  authorId?: number;
  parentId?: number | null; // null means get root items (no parent)
  visibility?: "public" | "private";
  search?: string;
}

export async function getItems(
  userId?: string,
  filters?: ItemFilters,
): Promise<ItemWithRelations[]> {
  await ensureSchemaInitialized();

  // Get userId from session
  const session = await getSession();
  if (!session?.user?.id && !userId) {
    return [];
  }
  const sessionUserId = session?.user.id ?? userId;
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
      category: {
        id: categories.id,
        name: categories.name,
      },
      location: {
        id: locations.id,
        title: locations.title,
      },
      author: {
        id: authors.id,
        name: authors.name,
      },
    })
    .from(items)
    .leftJoin(categories, eq(items.categoryId, categories.id))
    .leftJoin(locations, eq(items.locationId, locations.id))
    .leftJoin(authors, eq(items.authorId, authors.id))
    .orderBy(desc(items.updatedAt))
    .$dynamic();

  // Always filter by the authenticated user's ID
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
  id: number,
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
      category: {
        id: categories.id,
        name: categories.name,
      },
      location: {
        id: locations.id,
        title: locations.title,
      },
      author: {
        id: authors.id,
        name: authors.name,
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
  parentId: number,
): Promise<ItemWithRelations[]> {
  return getItems(undefined, { parentId });
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
      images,
      createdAt: now,
      updatedAt: now,
    };

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

    revalidatePath("/items");
    return { success: true, data: result[0] };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to create item",
    };
  }
}

export async function updateItemAction(
  id: number,
  data: Partial<Omit<NewItem, "id" | "userId" | "createdAt" | "updatedAt">>,
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

    // Verify ownership and get current item
    const existing = await db
      .select({ userId: items.userId, images: items.images })
      .from(items)
      .where(eq(items.id, id))
      .limit(1);

    if (!existing[0] || existing[0].userId !== resolvedUserId) {
      return { success: false, error: "Permission denied" };
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
      positions?: Array<{ positionSchemaId: number; data: Record<string, unknown> }>;
    };

    const result = await db
      .update(items)
      .set({ ...itemData, updatedAt: new Date() })
      .where(eq(items.id, id))
      .returning();

    // Create new positions if provided
    if (positionsData && positionsData.length > 0) {
      const now = new Date();
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
    return { success: true, data: result[0] };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to update item",
    };
  }
}

export async function deleteItemAction(
  id: number,
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

export async function deleteItemAndRedirect(id: number, userId?: string) {
  const result = await deleteItemAction(id, userId);
  if (result.success) {
    redirect("/items");
  }
  return result;
}

export async function deleteItemFormAction(
  id: number,
  userId?: string,
): Promise<void> {
  await deleteItemAction(id, userId);
  redirect("/items");
}

export async function searchItems(
  query: string,
  userId?: string,
  excludeId?: number,
  limit: number = 20,
): Promise<{ id: number; title: string }[]> {
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
      or(eq(items.userId, resolvedUserId), eq(items.visibility, "public")),
    );
  } else {
    // No user - only show public items
    conditions.push(eq(items.visibility, "public"));
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

  const results = await db
    .select({
      id: items.id,
      title: items.title,
    })
    .from(items)
    .where(conditions.length > 0 ? and(...conditions) : undefined)
    .orderBy(desc(items.updatedAt))
    .limit(limit);

  return results;
}
