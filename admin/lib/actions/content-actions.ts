"use server";

import { revalidatePath } from "next/cache";
import { eq } from "drizzle-orm";
import { db, contents, type Content, type NewContent, type ContentData } from "@/lib/db";

export async function getItemContents(itemId: number): Promise<Content[]> {
  return db
    .select()
    .from(contents)
    .where(eq(contents.itemId, itemId))
    .orderBy(contents.createdAt);
}

export async function getContent(id: number): Promise<Content | undefined> {
  const results = await db
    .select()
    .from(contents)
    .where(eq(contents.id, id))
    .limit(1);
  return results[0];
}

export async function createContentAction(
  data: Omit<NewContent, "id" | "createdAt" | "updatedAt">
): Promise<{ success: boolean; data?: Content; error?: string }> {
  try {
    const result = await db.insert(contents).values(data).returning();
    revalidatePath(`/items/${data.itemId}`);
    return { success: true, data: result[0] };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to create content",
    };
  }
}

export async function updateContentAction(
  id: number,
  data: Partial<{ type: "file" | "image" | "video"; data: ContentData }>
): Promise<{ success: boolean; data?: Content; error?: string }> {
  try {
    const result = await db
      .update(contents)
      .set({ ...data, updatedAt: new Date() })
      .where(eq(contents.id, id))
      .returning();

    if (result[0]) {
      revalidatePath(`/items/${result[0].itemId}`);
    }
    return { success: true, data: result[0] };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to update content",
    };
  }
}

export async function deleteContentAction(
  id: number
): Promise<{ success: boolean; error?: string }> {
  try {
    const content = await db
      .select({ itemId: contents.itemId })
      .from(contents)
      .where(eq(contents.id, id))
      .limit(1);

    await db.delete(contents).where(eq(contents.id, id));

    if (content[0]) {
      revalidatePath(`/items/${content[0].itemId}`);
    }
    return { success: true };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to delete content",
    };
  }
}
