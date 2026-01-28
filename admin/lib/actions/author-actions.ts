"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { eq } from "drizzle-orm";
import { db, authors, type Author, type NewAuthor } from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";

export async function getAuthors(): Promise<Author[]> {
  await ensureSchemaInitialized();
  return db.select().from(authors).orderBy(authors.name);
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
  data: Omit<NewAuthor, "id" | "createdAt" | "updatedAt">
): Promise<{ success: boolean; data?: Author; error?: string }> {
  try {
    const now = new Date();
    const result = await db
      .insert(authors)
      .values({
        ...data,
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
  data: Partial<Omit<NewAuthor, "id" | "createdAt" | "updatedAt">>
): Promise<{ success: boolean; data?: Author; error?: string }> {
  try {
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
  id: number
): Promise<{ success: boolean; error?: string }> {
  try {
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
  data: Omit<NewAuthor, "id" | "createdAt" | "updatedAt">
) {
  const result = await createAuthorAction(data);
  if (result.success) {
    redirect("/authors");
  }
  return result;
}

export async function deleteAuthorAndRedirect(id: number) {
  const result = await deleteAuthorAction(id);
  if (result.success) {
    redirect("/authors");
  }
  return result;
}

export async function deleteAuthorFormAction(id: number): Promise<void> {
  await deleteAuthorAction(id);
  revalidatePath("/authors");
}
