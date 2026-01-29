"use server";

import { revalidatePath } from "next/cache";
import { eq } from "drizzle-orm";
import { db, positions, positionSchemas, items, type Position, type NewPosition } from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";
import { getSession } from "@/lib/auth-helper";

export interface PositionWithSchema extends Position {
  positionSchema?: { id: number; name: string; schema: object } | null;
}

export async function getItemPositions(itemId: number): Promise<PositionWithSchema[]> {
  await ensureSchemaInitialized();
  const results = await db
    .select({
      id: positions.id,
      userId: positions.userId,
      itemId: positions.itemId,
      positionSchemaId: positions.positionSchemaId,
      data: positions.data,
      createdAt: positions.createdAt,
      updatedAt: positions.updatedAt,
      positionSchema: {
        id: positionSchemas.id,
        name: positionSchemas.name,
        schema: positionSchemas.schema,
      },
    })
    .from(positions)
    .leftJoin(positionSchemas, eq(positions.positionSchemaId, positionSchemas.id))
    .where(eq(positions.itemId, itemId));

  return results.map((row) => ({
    ...row,
    positionSchema: row.positionSchema?.id ? row.positionSchema : null,
  }));
}

export async function getPosition(id: number): Promise<PositionWithSchema | undefined> {
  const results = await db
    .select({
      id: positions.id,
      userId: positions.userId,
      itemId: positions.itemId,
      positionSchemaId: positions.positionSchemaId,
      data: positions.data,
      createdAt: positions.createdAt,
      updatedAt: positions.updatedAt,
      positionSchema: {
        id: positionSchemas.id,
        name: positionSchemas.name,
        schema: positionSchemas.schema,
      },
    })
    .from(positions)
    .leftJoin(positionSchemas, eq(positions.positionSchemaId, positionSchemas.id))
    .where(eq(positions.id, id))
    .limit(1);

  if (!results[0]) return undefined;

  const row = results[0];
  return {
    ...row,
    positionSchema: row.positionSchema?.id ? row.positionSchema : null,
  };
}

export async function createPositionAction(
  data: Omit<NewPosition, "id" | "userId" | "createdAt" | "updatedAt">,
  userId?: string
): Promise<{ success: boolean; data?: Position; error?: string }> {
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

    // Verify user owns the parent item
    const parentItem = await db
      .select({ userId: items.userId })
      .from(items)
      .where(eq(items.id, data.itemId))
      .limit(1);

    if (!parentItem[0] || parentItem[0].userId !== resolvedUserId) {
      return { success: false, error: "Permission denied" };
    }

    const result = await db.insert(positions).values({
      ...data,
      userId: resolvedUserId,
    }).returning();
    revalidatePath(`/items/${data.itemId}`);
    return { success: true, data: result[0] };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to create position",
    };
  }
}

export async function updatePositionAction(
  id: number,
  data: Partial<Omit<NewPosition, "id" | "userId" | "createdAt" | "updatedAt">>,
  userId?: string
): Promise<{ success: boolean; data?: Position; error?: string }> {
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
      .select({ userId: positions.userId, itemId: positions.itemId })
      .from(positions)
      .where(eq(positions.id, id))
      .limit(1);

    if (!existing[0] || existing[0].userId !== resolvedUserId) {
      return { success: false, error: "Permission denied" };
    }

    const result = await db
      .update(positions)
      .set({ ...data, updatedAt: new Date() })
      .where(eq(positions.id, id))
      .returning();

    if (result[0]) {
      revalidatePath(`/items/${result[0].itemId}`);
    }
    return { success: true, data: result[0] };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to update position",
    };
  }
}

export async function deletePositionAction(
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
      .select({ userId: positions.userId, itemId: positions.itemId })
      .from(positions)
      .where(eq(positions.id, id))
      .limit(1);

    if (!existing[0] || existing[0].userId !== resolvedUserId) {
      return { success: false, error: "Permission denied" };
    }

    await db.delete(positions).where(eq(positions.id, id));

    revalidatePath(`/items/${existing[0].itemId}`);
    return { success: true };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to delete position",
    };
  }
}
