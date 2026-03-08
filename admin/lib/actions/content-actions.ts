"use server";

import { revalidatePath } from "next/cache";
import { eq, and, or, lt, gt, like, sql, asc, desc, count as drizzleCount } from "drizzle-orm";
import { db, contents, type Content, type NewContent, type ContentData } from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";
import { deleteFileAction } from "@/lib/actions/file-actions";
import { isFileId } from "@/lib/utils/file-utils";
import {
  type PaginationParams,
  type PaginatedResult,
  DEFAULT_PAGE_SIZE,
  decodeCursor,
  buildPaginatedResponse,
} from "@/lib/utils/pagination";

export async function getItemContents(itemId: string, limit?: number): Promise<Content[]> {
  await ensureSchemaInitialized();
  let query = db
    .select()
    .from(contents)
    .where(eq(contents.itemId, itemId))
    .orderBy(contents.createdAt)
    .$dynamic();

  if (limit) {
    query = query.limit(limit);
  }

  return query;
}

export async function getItemContentsCount(itemId: string): Promise<number> {
  await ensureSchemaInitialized();
  const result = await db
    .select({ count: drizzleCount() })
    .from(contents)
    .where(eq(contents.itemId, itemId));
  return result[0]?.count ?? 0;
}

export interface ContentPaginatedFilters extends PaginationParams {
  search?: string;
}

export async function getItemContentsPaginated(
  itemId: string,
  filters?: ContentPaginatedFilters,
): Promise<PaginatedResult<Content>> {
  await ensureSchemaInitialized();

  const limit = filters?.limit ?? DEFAULT_PAGE_SIZE;
  const direction = filters?.direction ?? "next";
  const cursor = filters?.cursor ? decodeCursor(filters.cursor) : null;

  const conditions: ReturnType<typeof eq>[] = [eq(contents.itemId, itemId)];

  // Search on JSON data title field using SQLite json_extract
  if (filters?.search) {
    const searchCondition = like(
      sql`json_extract(${contents.data}, '$.title')`,
      `%${filters.search}%`,
    );
    conditions.push(searchCondition as ReturnType<typeof eq>);
  }

  // Capture base conditions before cursor conditions are added
  const baseConditions = [...conditions];

  // Cursor-based pagination (sorted by createdAt ASC, id ASC)
  if (cursor) {
    const cursorDate = new Date(cursor.sortValue);
    const cursorId = cursor.id;

    if (direction === "next") {
      const cursorCondition = or(
        gt(contents.createdAt, cursorDate),
        and(eq(contents.createdAt, cursorDate), gt(contents.id, cursorId)),
      );
      if (cursorCondition) conditions.push(cursorCondition as ReturnType<typeof eq>);
    } else {
      const cursorCondition = or(
        lt(contents.createdAt, cursorDate),
        and(eq(contents.createdAt, cursorDate), lt(contents.id, cursorId)),
      );
      if (cursorCondition) conditions.push(cursorCondition as ReturnType<typeof eq>);
    }
  }

  const orderDir = direction === "next" ? asc : desc;

  const [data, countResult] = await Promise.all([
    db
      .select()
      .from(contents)
      .where(and(...conditions))
      .orderBy(orderDir(contents.createdAt), orderDir(contents.id))
      .limit(limit + 1),
    db.select({ count: drizzleCount() }).from(contents).where(and(...baseConditions)),
  ]);
  const totalCount = countResult[0]?.count ?? 0;

  return buildPaginatedResponse(
    data,
    limit,
    direction,
    (item) => item.createdAt.toISOString(),
    !!cursor,
    totalCount,
  );
}

/**
 * Resolve file:xxx references in content data to signed S3 URLs.
 * Signs preview_image_url, preview_video_url, and file_path fields.
 */
export async function resolveContentFileRefs(
  contentList: Content[],
): Promise<Content[]> {
  const { signImagesArray } = await import("@/lib/actions/s3-upload-actions");

  // Collect all file references that need signing
  const fileRefs: string[] = [];
  const refMap: { contentIdx: number; field: string; refIdx: number }[] = [];

  for (let i = 0; i < contentList.length; i++) {
    const data = contentList[i].data as unknown as Record<string, unknown>;
    for (const field of ["preview_image_url", "preview_video_url", "file_path"]) {
      const val = data[field];
      if (typeof val === "string" && isFileId(val)) {
        refMap.push({ contentIdx: i, field, refIdx: fileRefs.length });
        fileRefs.push(val);
      }
    }
  }

  if (fileRefs.length === 0) return contentList;

  const signedUrls = await signImagesArray(fileRefs);

  // Clone contents and replace file refs with signed URLs
  const result = contentList.map((c) => ({ ...c, data: { ...(c.data as unknown as Record<string, unknown>) } }));
  for (const { contentIdx, field, refIdx } of refMap) {
    const signedUrl = signedUrls[refIdx];
    if (signedUrl) {
      (result[contentIdx].data as Record<string, unknown>)[field] = signedUrl;
    }
  }

  return result as unknown as Content[];
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
    const data = content.data as unknown as Record<string, unknown>;
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
