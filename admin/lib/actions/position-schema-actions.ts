"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { eq } from "drizzle-orm";
import { db, positionSchemas, type PositionSchema, type NewPositionSchema } from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";

export async function getPositionSchemas(): Promise<PositionSchema[]> {
  await ensureSchemaInitialized();
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
  data: Omit<NewPositionSchema, "id" | "createdAt" | "updatedAt">
): Promise<{ success: boolean; data?: PositionSchema; error?: string }> {
  try {
    const now = new Date();
    const result = await db
      .insert(positionSchemas)
      .values({
        ...data,
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
  data: Partial<Omit<NewPositionSchema, "id" | "createdAt" | "updatedAt">>
): Promise<{ success: boolean; data?: PositionSchema; error?: string }> {
  try {
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
  id: number
): Promise<{ success: boolean; error?: string }> {
  try {
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
  data: Omit<NewPositionSchema, "id" | "createdAt" | "updatedAt">
) {
  const result = await createPositionSchemaAction(data);
  if (result.success) {
    redirect("/position-schemas");
  }
  return result;
}

export async function deletePositionSchemaAndRedirect(id: number) {
  const result = await deletePositionSchemaAction(id);
  if (result.success) {
    redirect("/position-schemas");
  }
  return result;
}

export async function deletePositionSchemaFormAction(id: number): Promise<void> {
  await deletePositionSchemaAction(id);
  revalidatePath("/position-schemas");
}
