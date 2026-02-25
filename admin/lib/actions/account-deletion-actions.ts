"use server";

import { eq, and } from "drizzle-orm";
import { DeleteObjectCommand } from "@aws-sdk/client-s3";
import {
  db,
  items,
  categories,
  locations,
  authors,
  positions,
  positionSchemas,
  uploadFiles,
  accountDeletions,
} from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";
import { s3Client, S3_BUCKET } from "@/lib/s3";

/**
 * Get pending account deletion for a user
 */
export async function getAccountDeletionStatus(userId: string) {
  await ensureSchemaInitialized();

  const pending = await db
    .select()
    .from(accountDeletions)
    .where(
      and(
        eq(accountDeletions.userId, userId),
        eq(accountDeletions.status, "pending")
      )
    )
    .limit(1);

  return {
    pending: pending.length > 0,
    deletion: pending[0] ?? null,
  };
}

/**
 * Request account deletion - schedules deletion in 24 hours via QStash
 */
export async function requestAccountDeletion(
  userId: string,
  userEmail: string | null,
  callbackUrl: string
): Promise<{
  success: boolean;
  data?: (typeof accountDeletions)["$inferSelect"];
  error?: string;
}> {
  try {
    await ensureSchemaInitialized();

    // Check if there's already a pending deletion
    const existing = await getAccountDeletionStatus(userId);
    if (existing.pending) {
      return {
        success: false,
        error: "Account deletion already requested",
      };
    }

    const scheduledAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 hours from now
    let qstashMessageId: string | null = null;

    // Schedule QStash job for 24 hours delay (skip in e2e)
    if (process.env.IS_E2E !== "true") {
      try {
        const { Client } = await import("@upstash/qstash");
        const qstashClient = new Client({
          token: process.env.QSTASH_TOKEN!,
        });

        const result = await qstashClient.publishJSON({
          url: callbackUrl,
          body: { userId },
          delay: 24 * 60 * 60, // 24 hours in seconds
          headers: {
            "Content-Type": "application/json",
          },
        });

        qstashMessageId = result.messageId;
      } catch (error) {
        console.error("Failed to schedule QStash job:", error);
        return {
          success: false,
          error: "Failed to schedule account deletion",
        };
      }
    }

    const now = new Date();
    const [deletion] = await db
      .insert(accountDeletions)
      .values({
        userId,
        userEmail: userEmail,
        scheduledAt,
        qstashMessageId,
        status: "pending",
        createdAt: now,
        updatedAt: now,
      })
      .returning();

    return { success: true, data: deletion };
  } catch (error) {
    console.error("Failed to request account deletion:", error);
    return {
      success: false,
      error:
        error instanceof Error
          ? error.message
          : "Failed to request account deletion",
    };
  }
}

/**
 * Cancel a pending account deletion
 */
export async function cancelAccountDeletion(
  userId: string
): Promise<{ success: boolean; error?: string }> {
  try {
    await ensureSchemaInitialized();

    const existing = await getAccountDeletionStatus(userId);
    if (!existing.pending || !existing.deletion) {
      return {
        success: false,
        error: "No pending account deletion found",
      };
    }

    // Cancel QStash job (skip in e2e)
    if (
      process.env.IS_E2E !== "true" &&
      existing.deletion.qstashMessageId
    ) {
      try {
        const { Client } = await import("@upstash/qstash");
        const qstashClient = new Client({
          token: process.env.QSTASH_TOKEN!,
        });

        await qstashClient.messages.delete(
          existing.deletion.qstashMessageId
        );
      } catch (error) {
        console.error("Failed to cancel QStash job:", error);
        // Continue with cancellation even if QStash cancel fails
      }
    }

    await db
      .update(accountDeletions)
      .set({
        status: "cancelled",
        updatedAt: new Date(),
      })
      .where(eq(accountDeletions.id, existing.deletion.id));

    return { success: true };
  } catch (error) {
    console.error("Failed to cancel account deletion:", error);
    return {
      success: false,
      error:
        error instanceof Error
          ? error.message
          : "Failed to cancel account deletion",
    };
  }
}

/**
 * Execute account deletion - deletes all user data
 * Called by QStash callback after 24 hours
 */
export async function executeAccountDeletion(
  userId: string
): Promise<{ success: boolean; error?: string }> {
  try {
    await ensureSchemaInitialized();

    // Verify there's still a pending deletion
    const existing = await getAccountDeletionStatus(userId);
    if (!existing.pending) {
      return {
        success: false,
        error: "No pending account deletion found (may have been cancelled)",
      };
    }

    // Delete all user uploaded files from S3
    if (process.env.IS_E2E !== "true") {
      const userFiles = await db
        .select()
        .from(uploadFiles)
        .where(eq(uploadFiles.userId, userId));

      for (const file of userFiles) {
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

    // Delete all user data from database
    // Order matters due to foreign key constraints
    // Positions reference items and position schemas
    await db.delete(positions).where(eq(positions.userId, userId));

    // Upload files reference items
    await db.delete(uploadFiles).where(eq(uploadFiles.userId, userId));

    // Items reference categories, locations, authors
    await db.delete(items).where(eq(items.userId, userId));

    // Independent tables
    await db.delete(categories).where(eq(categories.userId, userId));
    await db.delete(locations).where(eq(locations.userId, userId));
    await db.delete(authors).where(eq(authors.userId, userId));
    await db.delete(positionSchemas).where(eq(positionSchemas.userId, userId));

    // Mark deletion as completed
    await db
      .update(accountDeletions)
      .set({
        status: "completed",
        updatedAt: new Date(),
      })
      .where(eq(accountDeletions.id, existing.deletion!.id));

    return { success: true };
  } catch (error) {
    console.error("Failed to execute account deletion:", error);
    return {
      success: false,
      error:
        error instanceof Error
          ? error.message
          : "Failed to execute account deletion",
    };
  }
}
