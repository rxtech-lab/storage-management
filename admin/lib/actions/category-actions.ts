"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { eq } from "drizzle-orm";
import { db, categories, type Category, type NewCategory } from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";

export async function getCategories(): Promise<Category[]> {
  await ensureSchemaInitialized();
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
  data: Omit<NewCategory, "id" | "createdAt" | "updatedAt">
): Promise<{ success: boolean; data?: Category; error?: string }> {
  try {
    const now = new Date();
    const result = await db
      .insert(categories)
      .values({
        ...data,
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
  data: Partial<Omit<NewCategory, "id" | "createdAt" | "updatedAt">>
): Promise<{ success: boolean; data?: Category; error?: string }> {
  try {
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
  id: number
): Promise<{ success: boolean; error?: string }> {
  try {
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
  data: Omit<NewCategory, "id" | "createdAt" | "updatedAt">
) {
  const result = await createCategoryAction(data);
  if (result.success) {
    redirect("/categories");
  }
  return result;
}

export async function deleteCategoryAndRedirect(id: number) {
  const result = await deleteCategoryAction(id);
  if (result.success) {
    redirect("/categories");
  }
  return result;
}

export async function deleteCategoryFormAction(id: number): Promise<void> {
  await deleteCategoryAction(id);
  revalidatePath("/categories");
}
