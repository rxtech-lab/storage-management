"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { eq, like, or, and, asc, desc, gt, lt } from "drizzle-orm";
import { db, authors, type Author, type NewAuthor } from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";
import { getSession } from "@/lib/auth-helper";
import {
  type PaginationParams,
  type PaginatedResult,
  decodeCursor,
  buildPaginatedResponse,
  DEFAULT_PAGE_SIZE,
} from "@/lib/utils/pagination";

export interface AuthorFilters {
  search?: string;
  limit?: number;
}

export interface PaginatedAuthorFilters extends AuthorFilters, PaginationParams {}

export async function getAuthors(userId?: string, filters?: AuthorFilters): Promise<Author[]> {
  await ensureSchemaInitialized();

  const conditions = [];

  if (userId) {
    conditions.push(eq(authors.userId, userId));
  }

  if (filters?.search) {
    const searchCondition = or(
      like(authors.name, `%${filters.search}%`),
      like(authors.bio, `%${filters.search}%`),
    );
    if (searchCondition) {
      conditions.push(searchCondition);
    }
  }

  let query = db.select().from(authors).orderBy(authors.name).$dynamic();

  if (conditions.length > 0) {
    query = query.where(and(...conditions));
  }

  if (filters?.limit) {
    query = query.limit(filters.limit);
  }

  return query;
}

export async function getAuthor(id: number): Promise<Author | undefined> {
  const results = await db
    .select()
    .from(authors)
    .where(eq(authors.id, id))
    .limit(1);
  return results[0];
}

export async function createAuthorAction(
  data: Omit<NewAuthor, "id" | "userId" | "createdAt" | "updatedAt">,
  userId?: string
): Promise<{ success: boolean; data?: Author; error?: string }> {
  try {
    // Get userId from session if not provided
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
      .insert(authors)
      .values({
        ...data,
        userId: resolvedUserId,
        createdAt: now,
        updatedAt: now,
      })
      .returning();
    revalidatePath("/authors");
    return { success: true, data: result[0] };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to create author",
    };
  }
}

export async function updateAuthorAction(
  id: number,
  data: Partial<Omit<NewAuthor, "id" | "userId" | "createdAt" | "updatedAt">>,
  userId?: string
): Promise<{ success: boolean; data?: Author; error?: string }> {
  try {
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
      .select({ userId: authors.userId })
      .from(authors)
      .where(eq(authors.id, id))
      .limit(1);

    if (!existing[0] || existing[0].userId !== resolvedUserId) {
      return { success: false, error: "Permission denied" };
    }

    const result = await db
      .update(authors)
      .set({ ...data, updatedAt: new Date() })
      .where(eq(authors.id, id))
      .returning();
    revalidatePath("/authors");
    revalidatePath(`/authors/${id}`);
    return { success: true, data: result[0] };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to update author",
    };
  }
}

export async function deleteAuthorAction(
  id: number,
  userId?: string
): Promise<{ success: boolean; error?: string }> {
  try {
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
      .select({ userId: authors.userId })
      .from(authors)
      .where(eq(authors.id, id))
      .limit(1);

    if (!existing[0] || existing[0].userId !== resolvedUserId) {
      return { success: false, error: "Permission denied" };
    }

    await db.delete(authors).where(eq(authors.id, id));
    revalidatePath("/authors");
    return { success: true };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to delete author",
    };
  }
}

export async function createAuthorAndRedirect(
  data: Omit<NewAuthor, "id" | "userId" | "createdAt" | "updatedAt">,
  userId?: string
) {
  const result = await createAuthorAction(data, userId);
  if (result.success) {
    redirect("/authors");
  }
  return result;
}

export async function deleteAuthorAndRedirect(id: number, userId?: string) {
  const result = await deleteAuthorAction(id, userId);
  if (result.success) {
    redirect("/authors");
  }
  return result;
}

export async function deleteAuthorFormAction(id: number): Promise<void> {
  await deleteAuthorAction(id);
  revalidatePath("/authors");
}

export async function searchAuthors(
  query: string,
  limit: number = 20
): Promise<{ id: number; name: string }[]> {
  await ensureSchemaInitialized();

  const session = await getSession();
  if (!session?.user?.id) {
    return [];
  }

  const conditions = [eq(authors.userId, session.user.id)];

  if (query) {
    const searchCondition = or(
      like(authors.name, `%${query}%`),
      like(authors.bio, `%${query}%`)
    );
    if (searchCondition) {
      conditions.push(searchCondition);
    }
  }

  const results = await db
    .select({ id: authors.id, name: authors.name })
    .from(authors)
    .where(and(...conditions))
    .orderBy(asc(authors.name))
    .limit(limit);

  return results;
}

export async function getAuthorsPaginated(
  userId?: string,
  filters?: PaginatedAuthorFilters
): Promise<PaginatedResult<Author>> {
  await ensureSchemaInitialized();

  // Get userId from session if not provided
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
      },
    };
  }

  const limit = filters?.limit ?? DEFAULT_PAGE_SIZE;
  const direction = filters?.direction ?? "next";
  const cursor = filters?.cursor ? decodeCursor(filters.cursor) : null;

  const conditions = [eq(authors.userId, resolvedUserId)];

  if (filters?.search) {
    const searchCondition = or(
      like(authors.name, `%${filters.search}%`),
      like(authors.bio, `%${filters.search}%`)
    );
    if (searchCondition) {
      conditions.push(searchCondition);
    }
  }

  // Add cursor conditions for pagination
  // Authors are sorted by name ASC, id ASC
  if (cursor) {
    const cursorName = String(cursor.sortValue);
    const cursorId = cursor.id;

    if (direction === "next") {
      const cursorCondition = or(
        gt(authors.name, cursorName),
        and(eq(authors.name, cursorName), gt(authors.id, cursorId))
      );
      if (cursorCondition) conditions.push(cursorCondition);
    } else {
      const cursorCondition = or(
        lt(authors.name, cursorName),
        and(eq(authors.name, cursorName), lt(authors.id, cursorId))
      );
      if (cursorCondition) conditions.push(cursorCondition);
    }
  }

  let query = db.select().from(authors).$dynamic();

  if (conditions.length > 0) {
    query = query.where(and(...conditions));
  }

  if (direction === "next") {
    query = query.orderBy(asc(authors.name), asc(authors.id));
  } else {
    query = query.orderBy(desc(authors.name), desc(authors.id));
  }

  query = query.limit(limit + 1);

  const results = await query;

  return buildPaginatedResponse(
    results,
    limit,
    direction,
    (item) => item.name,
    !!cursor
  );
}
