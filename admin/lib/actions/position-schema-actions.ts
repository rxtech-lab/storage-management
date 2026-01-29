"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { eq } from "drizzle-orm";
import { db, positionSchemas, type PositionSchema, type NewPositionSchema } from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";

export async function getPositionSchemas(userId?: string): Promise<PositionSchema[]> {
  await ensureSchemaInitialized();
  if (userId) {
    return db.select().from(positionSchemas).where(eq(positionSchemas.userId, userId)).orderBy(positionSchemas.name);
  }
  return db.select().from(positionSchemas).orderBy(positionSchemas.name);
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
  data: Omit<NewPositionSchema, "id" | "createdAt" | "updatedAt">,
  userId: string
): Promise<{ success: boolean; data?: PositionSchema; error?: string }> {
  try {
    const now = new Date();
    const result = await db
      .insert(positionSchemas)
      .values({
        ...data,
        userId,
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
  data: Partial<Omit<NewPositionSchema, "id" | "createdAt" | "updatedAt">>,
  userId: string
): Promise<{ success: boolean; data?: PositionSchema; error?: string }> {
  try {
    // Verify ownership
    const existing = await db
      .select({ userId: positionSchemas.userId })
      .from(positionSchemas)
      .where(eq(positionSchemas.id, id))
      .limit(1);

    if (!existing[0] || existing[0].userId !== userId) {
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
  userId: string
): Promise<{ success: boolean; error?: string }> {
  try {
    // Verify ownership
    const existing = await db
      .select({ userId: positionSchemas.userId })
      .from(positionSchemas)
      .where(eq(positionSchemas.id, id))
      .limit(1);

    if (!existing[0] || existing[0].userId !== userId) {
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
  data: Omit<NewPositionSchema, "id" | "createdAt" | "updatedAt">,
  userId: string
) {
  const result = await createPositionSchemaAction(data, userId);
  if (result.success) {
    redirect("/position-schemas");
  }
  return result;
}

export async function deletePositionSchemaAndRedirect(id: number, userId: string) {
  const result = await deletePositionSchemaAction(id, userId);
  if (result.success) {
    redirect("/position-schemas");
  }
  return result;
}

export async function deletePositionSchemaFormAction(id: number, userId: string): Promise<void> {
  await deletePositionSchemaAction(id, userId);
  revalidatePath("/position-schemas");
}
