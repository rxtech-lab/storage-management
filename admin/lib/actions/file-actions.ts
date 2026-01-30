"use server";

import { eq, and, inArray } from "drizzle-orm";
import { HeadObjectCommand, DeleteObjectCommand } from "@aws-sdk/client-s3";
import { db, uploadFiles, type UploadFile, type NewUploadFile } from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";
import { s3Client, S3_BUCKET } from "@/lib/s3";
import { getSession } from "@/lib/auth-helper";

export interface CreateFileRecordData {
  key: string;
  filename: string;
  contentType: string;
  size: number;
}

/**
 * Create a file record in the database after S3 upload
 */
export async function createFileRecordAction(
  data: CreateFileRecordData,
  userId?: string
): Promise<{ success: boolean; data?: UploadFile; error?: string }> {
  try {
    await ensureSchemaInitialized();

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
      .insert(uploadFiles)
      .values({
        userId: resolvedUserId,
        key: data.key,
        filename: data.filename,
        contentType: data.contentType,
        size: data.size,
        createdAt: now,
      })
      .returning();

    return { success: true, data: result[0] };
  } catch (error) {
    console.error("Failed to create file record:", error);
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to create file record",
    };
  }
}

/**
 * Get a file record by ID
 */
export async function getFile(id: number): Promise<UploadFile | undefined> {
  await ensureSchemaInitialized();
  const results = await db
    .select()
    .from(uploadFiles)
    .where(eq(uploadFiles.id, id))
    .limit(1);
  return results[0];
}

/**
 * Get multiple file records by IDs
 */
export async function getFiles(ids: number[]): Promise<UploadFile[]> {
  if (ids.length === 0) return [];
  await ensureSchemaInitialized();
  return db.select().from(uploadFiles).where(inArray(uploadFiles.id, ids));
}

/**
 * Get files by item ID
 */
export async function getFilesByItemId(itemId: number): Promise<UploadFile[]> {
  await ensureSchemaInitialized();
  return db.select().from(uploadFiles).where(eq(uploadFiles.itemId, itemId));
}

/**
 * Validate that file IDs exist and belong to the user
 */
export async function validateFileOwnership(
  fileIds: number[],
  userId: string
): Promise<{ valid: boolean; invalidIds: number[]; error?: string }> {
  if (fileIds.length === 0) {
    return { valid: true, invalidIds: [] };
  }

  await ensureSchemaInitialized();
  const files = await db
    .select({ id: uploadFiles.id, userId: uploadFiles.userId })
    .from(uploadFiles)
    .where(inArray(uploadFiles.id, fileIds));

  const foundIds = new Set(files.map((f) => f.id));
  const invalidIds: number[] = [];

  for (const id of fileIds) {
    if (!foundIds.has(id)) {
      invalidIds.push(id);
    }
  }

  // Check ownership
  for (const file of files) {
    if (file.userId !== userId) {
      invalidIds.push(file.id);
    }
  }

  return {
    valid: invalidIds.length === 0,
    invalidIds,
    error: invalidIds.length > 0 ? `Invalid or unauthorized file IDs: ${invalidIds.join(", ")}` : undefined,
  };
}

/**
 * Verify that files exist in S3 via HeadObject
 * Skips verification in E2E mode
 */
export async function validateFilesExistInS3(
  fileIds: number[]
): Promise<{ valid: boolean; missingIds: number[]; error?: string }> {
  if (fileIds.length === 0) {
    return { valid: true, missingIds: [] };
  }

  // Skip S3 validation in E2E mode
  if (process.env.IS_E2E === "true") {
    return { valid: true, missingIds: [] };
  }

  await ensureSchemaInitialized();
  const files = await getFiles(fileIds);
  const missingIds: number[] = [];

  for (const file of files) {
    try {
      const command = new HeadObjectCommand({
        Bucket: S3_BUCKET,
        Key: file.key,
      });
      await s3Client.send(command);
    } catch (error) {
      // File does not exist in S3
      missingIds.push(file.id);
    }
  }

  return {
    valid: missingIds.length === 0,
    missingIds,
    error: missingIds.length > 0 ? `Files not found in storage: ${missingIds.join(", ")}` : undefined,
  };
}

/**
 * Associate files with an item
 */
export async function associateFilesWithItem(
  fileIds: number[],
  itemId: number,
  userId: string
): Promise<{ success: boolean; error?: string }> {
  if (fileIds.length === 0) {
    return { success: true };
  }

  try {
    await ensureSchemaInitialized();

    // Validate ownership first
    const ownershipResult = await validateFileOwnership(fileIds, userId);
    if (!ownershipResult.valid) {
      return { success: false, error: ownershipResult.error };
    }

    // Update files to associate with item
    await db
      .update(uploadFiles)
      .set({ itemId })
      .where(inArray(uploadFiles.id, fileIds));

    return { success: true };
  } catch (error) {
    console.error("Failed to associate files with item:", error);
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to associate files",
    };
  }
}

/**
 * Disassociate files from an item (set itemId to null)
 */
export async function disassociateFilesFromItem(
  fileIds: number[]
): Promise<{ success: boolean; error?: string }> {
  if (fileIds.length === 0) {
    return { success: true };
  }

  try {
    await ensureSchemaInitialized();
    await db
      .update(uploadFiles)
      .set({ itemId: null })
      .where(inArray(uploadFiles.id, fileIds));

    return { success: true };
  } catch (error) {
    console.error("Failed to disassociate files from item:", error);
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to disassociate files",
    };
  }
}

/**
 * Delete a file record and its S3 object
 */
export async function deleteFileAction(
  id: number,
  userId?: string
): Promise<{ success: boolean; error?: string }> {
  try {
    await ensureSchemaInitialized();

    let resolvedUserId = userId;
    if (!resolvedUserId) {
      const session = await getSession();
      if (!session?.user?.id) {
        return { success: false, error: "Unauthorized" };
      }
      resolvedUserId = session.user.id;
    }

    // Get file to verify ownership and get key
    const file = await getFile(id);
    if (!file) {
      return { success: false, error: "File not found" };
    }
    if (file.userId !== resolvedUserId) {
      return { success: false, error: "Permission denied" };
    }

    // Delete from S3 (fire-and-forget in non-E2E mode)
    if (process.env.IS_E2E !== "true") {
      try {
        const command = new DeleteObjectCommand({
          Bucket: S3_BUCKET,
          Key: file.key,
        });
        await s3Client.send(command);
      } catch (error) {
        console.error("Failed to delete file from S3:", error);
        // Continue with database deletion even if S3 deletion fails
      }
    }

    // Delete from database
    await db.delete(uploadFiles).where(eq(uploadFiles.id, id));

    return { success: true };
  } catch (error) {
    console.error("Failed to delete file:", error);
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to delete file",
    };
  }
}

/**
 * Delete all files associated with an item
 * Called when an item is deleted
 */
export async function deleteFilesForItem(
  itemId: number
): Promise<{ success: boolean; error?: string }> {
  try {
    await ensureSchemaInitialized();

    // Get all files for the item
    const files = await getFilesByItemId(itemId);

    if (files.length === 0) {
      return { success: true };
    }

    // Delete from S3 (fire-and-forget)
    if (process.env.IS_E2E !== "true") {
      for (const file of files) {
        try {
          const command = new DeleteObjectCommand({
            Bucket: S3_BUCKET,
            Key: file.key,
          });
          await s3Client.send(command);
        } catch (error) {
          console.error(`Failed to delete file ${file.key} from S3:`, error);
          // Continue with other deletions
        }
      }
    }

    // Delete file records from database
    const fileIds = files.map((f) => f.id);
    await db.delete(uploadFiles).where(inArray(uploadFiles.id, fileIds));

    return { success: true };
  } catch (error) {
    console.error("Failed to delete files for item:", error);
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to delete files",
    };
  }
}
