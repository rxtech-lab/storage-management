"use server";

import { revalidatePath } from "next/cache";
import { eq, like, or, and, asc, desc, gt, lt, count } from "drizzle-orm";
import { db, tags, itemTags, type Tag, type NewTag } from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";
import { getSession } from "@/lib/auth-helper";
import {
  type PaginationParams,
  type PaginatedResult,
  decodeCursor,
  buildPaginatedResponse,
  DEFAULT_PAGE_SIZE,
} from "@/lib/utils/pagination";

export interface TagFilters {
  search?: string;
  limit?: number;
}

export interface PaginatedTagFilters extends TagFilters, PaginationParams {}

export async function getTags(userId?: string, filters?: TagFilters): Promise<Tag[]> {
  await ensureSchemaInitialized();

  const conditions = [];

  if (userId) {
    conditions.push(eq(tags.userId, userId));
  }

  if (filters?.search) {
    const searchCondition = like(tags.title, `%${filters.search}%`);
    if (searchCondition) {
      conditions.push(searchCondition);
    }
  }

  let query = db.select().from(tags).orderBy(tags.title).$dynamic();

  if (conditions.length > 0) {
    query = query.where(and(...conditions));
  }

  if (filters?.limit) {
    query = query.limit(filters.limit);
  }

  return query;
}

export async function getTag(id: string): Promise<Tag | undefined> {
  const results = await db
    .select()
    .from(tags)
    .where(eq(tags.id, id))
    .limit(1);
  return results[0];
}

export async function createTagAction(
  data: Omit<NewTag, "id" | "userId" | "createdAt" | "updatedAt">,
  userId?: string
): Promise<{ success: boolean; data?: Tag; error?: string }> {
  try {
    let resolvedUserId = userId;
    if (!resolvedUserId) {
      const session = await getSession();
      if (!session?.user?.id) {
        return { success: false, error: "Unauthorized" };
      }
      resolvedUserId = session.user.id;
    }

    const now = new Date();
    const result = await db
      .insert(tags)
      .values({
        ...data,
        userId: resolvedUserId,
        createdAt: now,
        updatedAt: now,
      })
      .returning();
    revalidatePath("/tags");
    return { success: true, data: result[0] };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to create tag",
    };
  }
}

export async function updateTagAction(
  id: string,
  data: Partial<Omit<NewTag, "id" | "userId" | "createdAt" | "updatedAt">>,
  userId?: string
): Promise<{ success: boolean; data?: Tag; error?: string }> {
  try {
    let resolvedUserId = userId;
    if (!resolvedUserId) {
      const session = await getSession();
      if (!session?.user?.id) {
        return { success: false, error: "Unauthorized" };
      }
      resolvedUserId = session.user.id;
    }

    const existing = await db
      .select({ userId: tags.userId })
      .from(tags)
      .where(eq(tags.id, id))
      .limit(1);

    if (!existing[0] || existing[0].userId !== resolvedUserId) {
      return { success: false, error: "Permission denied" };
    }

    const result = await db
      .update(tags)
      .set({ ...data, updatedAt: new Date() })
      .where(eq(tags.id, id))
      .returning();
    revalidatePath("/tags");
    return { success: true, data: result[0] };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to update tag",
    };
  }
}

export async function deleteTagAction(
  id: string,
  userId?: string
): Promise<{ success: boolean; error?: string }> {
  try {
    let resolvedUserId = userId;
    if (!resolvedUserId) {
      const session = await getSession();
      if (!session?.user?.id) {
        return { success: false, error: "Unauthorized" };
      }
      resolvedUserId = session.user.id;
    }

    const existing = await db
      .select({ userId: tags.userId })
      .from(tags)
      .where(eq(tags.id, id))
      .limit(1);

    if (!existing[0] || existing[0].userId !== resolvedUserId) {
      return { success: false, error: "Permission denied" };
    }

    await db.delete(tags).where(eq(tags.id, id));
    revalidatePath("/tags");
    return { success: true };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to delete tag",
    };
  }
}

export async function searchTags(
  query: string,
  limit: number = 20
): Promise<{ id: string; title: string; color: string }[]> {
  await ensureSchemaInitialized();

  const session = await getSession();
  if (!session?.user?.id) {
    return [];
  }

  const conditions = [eq(tags.userId, session.user.id)];

  if (query) {
    conditions.push(like(tags.title, `%${query}%`));
  }

  const results = await db
    .select({ id: tags.id, title: tags.title, color: tags.color })
    .from(tags)
    .where(and(...conditions))
    .orderBy(asc(tags.title))
    .limit(limit);

  return results;
}

export async function getTagsPaginated(
  userId?: string,
  filters?: PaginatedTagFilters
): Promise<PaginatedResult<Tag>> {
  await ensureSchemaInitialized();

  let resolvedUserId = userId;
  if (!resolvedUserId) {
    const session = await getSession();
    resolvedUserId = session?.user?.id;
  }

  if (!resolvedUserId) {
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

  const conditions = [eq(tags.userId, resolvedUserId)];

  if (filters?.search) {
    conditions.push(like(tags.title, `%${filters.search}%`));
  }

  // Capture base conditions before cursor conditions are added
  const baseConditions = [...conditions];

  if (cursor) {
    const cursorTitle = String(cursor.sortValue);
    const cursorId = cursor.id;

    if (direction === "next") {
      const cursorCondition = or(
        gt(tags.title, cursorTitle),
        and(eq(tags.title, cursorTitle), gt(tags.id, cursorId))
      );
      if (cursorCondition) conditions.push(cursorCondition);
    } else {
      const cursorCondition = or(
        lt(tags.title, cursorTitle),
        and(eq(tags.title, cursorTitle), lt(tags.id, cursorId))
      );
      if (cursorCondition) conditions.push(cursorCondition);
    }
  }

  let query = db.select().from(tags).$dynamic();

  if (conditions.length > 0) {
    query = query.where(and(...conditions));
  }

  if (direction === "next") {
    query = query.orderBy(asc(tags.title), asc(tags.id));
  } else {
    query = query.orderBy(desc(tags.title), desc(tags.id));
  }

  query = query.limit(limit + 1);

  const [results, countResult] = await Promise.all([
    query,
    db.select({ count: count() }).from(tags).where(and(...baseConditions)),
  ]);
  const totalCount = countResult[0]?.count ?? 0;

  return buildPaginatedResponse(
    results,
    limit,
    direction,
    (item) => item.title,
    !!cursor,
    totalCount
  );
}

export async function deleteTagFormAction(id: string): Promise<void> {
  await deleteTagAction(id);
  revalidatePath("/tags");
}

// Item-Tag junction operations

export async function getItemTags(itemId: string): Promise<{ id: string; title: string; color: string }[]> {
  await ensureSchemaInitialized();

  const results = await db
    .select({
      id: tags.id,
      title: tags.title,
      color: tags.color,
    })
    .from(itemTags)
    .innerJoin(tags, eq(itemTags.tagId, tags.id))
    .where(eq(itemTags.itemId, itemId))
    .orderBy(asc(tags.title));

  return results;
}

export async function addItemTag(
  itemId: string,
  tagId: string
): Promise<{ success: boolean; error?: string }> {
  try {
    await db.insert(itemTags).values({
      itemId,
      tagId,
      createdAt: new Date(),
    });
    revalidatePath(`/items/${itemId}`);
    return { success: true };
  } catch (error) {
    if (error instanceof Error && error.message.includes("UNIQUE")) {
      return { success: false, error: "Tag already added to this item" };
    }
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to add tag",
    };
  }
}

export async function removeItemTag(
  itemId: string,
  tagId: string
): Promise<{ success: boolean; error?: string }> {
  try {
    await db
      .delete(itemTags)
      .where(and(eq(itemTags.itemId, itemId), eq(itemTags.tagId, tagId)));
    revalidatePath(`/items/${itemId}`);
    return { success: true };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to remove tag",
    };
  }
}
