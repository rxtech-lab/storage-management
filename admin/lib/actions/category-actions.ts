"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { eq, like, or, and, asc, desc, gt, lt } from "drizzle-orm";
import { db, categories, type Category, type NewCategory } from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";
import { getSession } from "@/lib/auth-helper";
import {
  type PaginationParams,
  type PaginatedResult,
  decodeCursor,
  buildPaginatedResponse,
  DEFAULT_PAGE_SIZE,
} from "@/lib/utils/pagination";

export interface CategoryFilters {
  search?: string;
  limit?: number;
}

export interface PaginatedCategoryFilters extends CategoryFilters, PaginationParams {}

export async function getCategories(userId?: string, filters?: CategoryFilters): Promise<Category[]> {
  await ensureSchemaInitialized();

  const conditions = [];

  if (userId) {
    conditions.push(eq(categories.userId, userId));
  }

  if (filters?.search) {
    const searchCondition = or(
      like(categories.name, `%${filters.search}%`),
      like(categories.description, `%${filters.search}%`),
    );
    if (searchCondition) {
      conditions.push(searchCondition);
    }
  }

  let query = db.select().from(categories).orderBy(categories.name).$dynamic();

  if (conditions.length > 0) {
    query = query.where(and(...conditions));
  }

  if (filters?.limit) {
    query = query.limit(filters.limit);
  }

  return query;
}

export async function getCategory(id: number): Promise<Category | undefined> {
  const results = await db
    .select()
    .from(categories)
    .where(eq(categories.id, id))
    .limit(1);
  return results[0];
}

export async function createCategoryAction(
  data: Omit<NewCategory, "id" | "userId" | "createdAt" | "updatedAt">,
  userId?: string
): Promise<{ success: boolean; data?: Category; error?: string }> {
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
      .insert(categories)
      .values({
        ...data,
        userId: resolvedUserId,
        createdAt: now,
        updatedAt: now,
      })
      .returning();
    revalidatePath("/categories");
    return { success: true, data: result[0] };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to create category",
    };
  }
}

export async function updateCategoryAction(
  id: number,
  data: Partial<Omit<NewCategory, "id" | "userId" | "createdAt" | "updatedAt">>,
  userId?: string
): Promise<{ success: boolean; data?: Category; error?: string }> {
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
      .select({ userId: categories.userId })
      .from(categories)
      .where(eq(categories.id, id))
      .limit(1);

    if (!existing[0] || existing[0].userId !== resolvedUserId) {
      return { success: false, error: "Permission denied" };
    }

    const result = await db
      .update(categories)
      .set({ ...data, updatedAt: new Date() })
      .where(eq(categories.id, id))
      .returning();
    revalidatePath("/categories");
    revalidatePath(`/categories/${id}`);
    return { success: true, data: result[0] };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to update category",
    };
  }
}

export async function deleteCategoryAction(
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
      .select({ userId: categories.userId })
      .from(categories)
      .where(eq(categories.id, id))
      .limit(1);

    if (!existing[0] || existing[0].userId !== resolvedUserId) {
      return { success: false, error: "Permission denied" };
    }

    await db.delete(categories).where(eq(categories.id, id));
    revalidatePath("/categories");
    return { success: true };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to delete category",
    };
  }
}

export async function createCategoryAndRedirect(
  data: Omit<NewCategory, "id" | "userId" | "createdAt" | "updatedAt">,
  userId?: string
) {
  const result = await createCategoryAction(data, userId);
  if (result.success) {
    redirect("/categories");
  }
  return result;
}

export async function deleteCategoryAndRedirect(id: number, userId?: string) {
  const result = await deleteCategoryAction(id, userId);
  if (result.success) {
    redirect("/categories");
  }
  return result;
}

export async function deleteCategoryFormAction(id: number): Promise<void> {
  await deleteCategoryAction(id);
  revalidatePath("/categories");
}

export async function getCategoriesPaginated(
  userId?: string,
  filters?: PaginatedCategoryFilters
): Promise<PaginatedResult<Category>> {
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

  const conditions = [eq(categories.userId, resolvedUserId)];

  if (filters?.search) {
    const searchCondition = or(
      like(categories.name, `%${filters.search}%`),
      like(categories.description, `%${filters.search}%`)
    );
    if (searchCondition) {
      conditions.push(searchCondition);
    }
  }

  // Add cursor conditions for pagination
  // Categories are sorted by name ASC, id ASC
  if (cursor) {
    const cursorName = String(cursor.sortValue);
    const cursorId = cursor.id;

    if (direction === "next") {
      // Forward pagination: get items after cursor (name > cursorName OR name = cursorName AND id > cursorId)
      const cursorCondition = or(
        gt(categories.name, cursorName),
        and(eq(categories.name, cursorName), gt(categories.id, cursorId))
      );
      if (cursorCondition) conditions.push(cursorCondition);
    } else {
      // Backward pagination: get items before cursor
      const cursorCondition = or(
        lt(categories.name, cursorName),
        and(eq(categories.name, cursorName), lt(categories.id, cursorId))
      );
      if (cursorCondition) conditions.push(cursorCondition);
    }
  }

  let query = db.select().from(categories).$dynamic();

  if (conditions.length > 0) {
    query = query.where(and(...conditions));
  }

  // Order depends on direction
  if (direction === "next") {
    query = query.orderBy(asc(categories.name), asc(categories.id));
  } else {
    // Reverse order for backward pagination
    query = query.orderBy(desc(categories.name), desc(categories.id));
  }

  // Fetch one extra to determine if there are more items
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
