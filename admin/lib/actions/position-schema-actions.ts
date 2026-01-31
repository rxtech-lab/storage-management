"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { eq, like, and } from "drizzle-orm";
import { db, positionSchemas, type PositionSchema, type NewPositionSchema } from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";
import { getSession } from "@/lib/auth-helper";

export interface PositionSchemaFilters {
  search?: string;
  limit?: number;
}

export async function getPositionSchemas(userId?: string, filters?: PositionSchemaFilters): Promise<PositionSchema[]> {
  await ensureSchemaInitialized();

  const conditions = [];

  if (userId) {
    conditions.push(eq(positionSchemas.userId, userId));
  }

  if (filters?.search) {
    conditions.push(like(positionSchemas.name, `%${filters.search}%`));
  }

  let query = db.select().from(positionSchemas).orderBy(positionSchemas.name).$dynamic();

  if (conditions.length > 0) {
    query = query.where(and(...conditions));
  }

  if (filters?.limit) {
    query = query.limit(filters.limit);
  }

  return query;
}

export async function getPositionSchema(id: number): Promise<PositionSchema | undefined> {
  const results = await db
    .select()
    .from(positionSchemas)
    .where(eq(positionSchemas.id, id))
    .limit(1);
  return results[0];
}

export async function createPositionSchemaAction(
  data: Omit<NewPositionSchema, "id" | "userId" | "createdAt" | "updatedAt">,
  userId?: string
): Promise<{ success: boolean; data?: PositionSchema; error?: string }> {
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
      .insert(positionSchemas)
      .values({
        ...data,
        userId: resolvedUserId,
        createdAt: now,
        updatedAt: now,
      })
      .returning();
    revalidatePath("/position-schemas");
    return { success: true, data: result[0] };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to create position schema",
    };
  }
}

export async function updatePositionSchemaAction(
  id: number,
  data: Partial<Omit<NewPositionSchema, "id" | "userId" | "createdAt" | "updatedAt">>,
  userId?: string
): Promise<{ success: boolean; data?: PositionSchema; error?: string }> {
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
      .select({ userId: positionSchemas.userId })
      .from(positionSchemas)
      .where(eq(positionSchemas.id, id))
      .limit(1);

    if (!existing[0] || existing[0].userId !== resolvedUserId) {
      return { success: false, error: "Permission denied" };
    }

    const result = await db
      .update(positionSchemas)
      .set({ ...data, updatedAt: new Date() })
      .where(eq(positionSchemas.id, id))
      .returning();
    revalidatePath("/position-schemas");
    revalidatePath(`/position-schemas/${id}`);
    return { success: true, data: result[0] };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to update position schema",
    };
  }
}

export async function deletePositionSchemaAction(
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
      .select({ userId: positionSchemas.userId })
      .from(positionSchemas)
      .where(eq(positionSchemas.id, id))
      .limit(1);

    if (!existing[0] || existing[0].userId !== resolvedUserId) {
      return { success: false, error: "Permission denied" };
    }

    await db.delete(positionSchemas).where(eq(positionSchemas.id, id));
    revalidatePath("/position-schemas");
    return { success: true };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to delete position schema",
    };
  }
}

export async function createPositionSchemaAndRedirect(
  data: Omit<NewPositionSchema, "id" | "userId" | "createdAt" | "updatedAt">,
  userId?: string
) {
  const result = await createPositionSchemaAction(data, userId);
  if (result.success) {
    redirect("/position-schemas");
  }
  return result;
}

export async function deletePositionSchemaAndRedirect(id: number, userId?: string) {
  const result = await deletePositionSchemaAction(id, userId);
  if (result.success) {
    redirect("/position-schemas");
  }
  return result;
}

export async function deletePositionSchemaFormAction(id: number): Promise<void> {
  await deletePositionSchemaAction(id);
  revalidatePath("/position-schemas");
}
