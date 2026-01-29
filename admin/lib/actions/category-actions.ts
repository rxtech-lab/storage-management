"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { eq } from "drizzle-orm";
import { db, categories, type Category, type NewCategory } from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";

export async function getCategories(userId?: string): Promise<Category[]> {
  await ensureSchemaInitialized();
  if (userId) {
    return db.select().from(categories).where(eq(categories.userId, userId)).orderBy(categories.name);
  }
  return db.select().from(categories).orderBy(categories.name);
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
  data: Omit<NewCategory, "id" | "createdAt" | "updatedAt">,
  userId: string
): Promise<{ success: boolean; data?: Category; error?: string }> {
  try {
    const now = new Date();
    const result = await db
      .insert(categories)
      .values({
        ...data,
        userId,
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
  data: Partial<Omit<NewCategory, "id" | "createdAt" | "updatedAt">>,
  userId: string
): Promise<{ success: boolean; data?: Category; error?: string }> {
  try {
    // Verify ownership
    const existing = await db
      .select({ userId: categories.userId })
      .from(categories)
      .where(eq(categories.id, id))
      .limit(1);

    if (!existing[0] || existing[0].userId !== userId) {
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
  userId: string
): Promise<{ success: boolean; error?: string }> {
  try {
    // Verify ownership
    const existing = await db
      .select({ userId: categories.userId })
      .from(categories)
      .where(eq(categories.id, id))
      .limit(1);

    if (!existing[0] || existing[0].userId !== userId) {
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
  data: Omit<NewCategory, "id" | "createdAt" | "updatedAt">,
  userId: string
) {
  const result = await createCategoryAction(data, userId);
  if (result.success) {
    redirect("/categories");
  }
  return result;
}

export async function deleteCategoryAndRedirect(id: number, userId: string) {
  const result = await deleteCategoryAction(id, userId);
  if (result.success) {
    redirect("/categories");
  }
  return result;
}

export async function deleteCategoryFormAction(id: number, userId: string): Promise<void> {
  await deleteCategoryAction(id, userId);
  revalidatePath("/categories");
}
