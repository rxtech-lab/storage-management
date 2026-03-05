"use server";

import { revalidatePath } from "next/cache";
import { eq } from "drizzle-orm";
import { db, contents, type Content, type NewContent, type ContentData } from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";
import { deleteFileAction } from "@/lib/actions/file-actions";
import { isFileId } from "@/lib/utils/file-utils";

export async function getItemContents(itemId: string): Promise<Content[]> {
  await ensureSchemaInitialized();
  return db
    .select()
    .from(contents)
    .where(eq(contents.itemId, itemId))
    .orderBy(contents.createdAt);
}

export async function getContent(id: string): Promise<Content | undefined> {
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
  id: string,
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
  id: string
): Promise<{ success: boolean; error?: string }> {
  try {
    const result = await db
      .select()
      .from(contents)
      .where(eq(contents.id, id))
      .limit(1);

    const content = result[0];
    if (!content) {
      return { success: false, error: "Content not found" };
    }

    // Extract file IDs from content data and delete associated files + S3 objects
    const data = content.data as Record<string, unknown>;
    const fileRefs = [data.preview_image_url, data.preview_video_url].filter(
      (ref): ref is string => typeof ref === "string" && isFileId(ref)
    );

    for (const ref of fileRefs) {
      const fileId = ref.substring(5);
      await deleteFileAction(fileId);
    }

    await db.delete(contents).where(eq(contents.id, id));

    revalidatePath(`/items/${content.itemId}`);
    return { success: true };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to delete content",
    };
  }
}
