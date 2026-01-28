"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { eq, like, or, desc, isNull, and, ne } from "drizzle-orm";
import { db, items, categories, locations, authors, type Item, type NewItem } from "@/lib/db";

export interface ItemWithRelations extends Item {
  category?: { id: number; name: string } | null;
  location?: { id: number; title: string } | null;
  author?: { id: number; name: string } | null;
  parent?: { id: number; title: string } | null;
}

export interface ItemFilters {
  categoryId?: number;
  locationId?: number;
  authorId?: number;
  parentId?: number | null; // null means get root items (no parent)
  visibility?: "public" | "private";
  search?: string;
}

export async function getItems(filters?: ItemFilters): Promise<ItemWithRelations[]> {
  let query = db
    .select({
      id: items.id,
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

  const conditions = [];

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
    conditions.push(
      or(
        like(items.title, `%${filters.search}%`),
        like(items.description, `%${filters.search}%`)
      )
    );
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

export async function getItem(id: number): Promise<ItemWithRelations | undefined> {
  const results = await db
    .select({
      id: items.id,
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

export async function getItemChildren(parentId: number): Promise<ItemWithRelations[]> {
  return getItems({ parentId });
}

export async function createItemAction(
  data: Omit<NewItem, "id" | "createdAt" | "updatedAt">
): Promise<{ success: boolean; data?: Item; error?: string }> {
  try {
    const result = await db.insert(items).values(data).returning();
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
  data: Partial<Omit<NewItem, "id" | "createdAt" | "updatedAt">>
): Promise<{ success: boolean; data?: Item; error?: string }> {
  try {
    const result = await db
      .update(items)
      .set({ ...data, updatedAt: new Date() })
      .where(eq(items.id, id))
      .returning();
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
  id: number
): Promise<{ success: boolean; error?: string }> {
  try {
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
  data: Omit<NewItem, "id" | "createdAt" | "updatedAt">
) {
  const result = await createItemAction(data);
  if (result.success && result.data) {
    redirect(`/items/${result.data.id}`);
  }
  return result;
}

export async function deleteItemAndRedirect(id: number) {
  const result = await deleteItemAction(id);
  if (result.success) {
    redirect("/items");
  }
  return result;
}

export async function deleteItemFormAction(id: number): Promise<void> {
  await deleteItemAction(id);
  redirect("/items");
}

export async function searchItems(
  query: string,
  excludeId?: number,
  limit: number = 20
): Promise<{ id: number; title: string }[]> {
  const conditions = [];

  if (query) {
    conditions.push(
      or(
        like(items.title, `%${query}%`),
        like(items.description, `%${query}%`)
      )
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
