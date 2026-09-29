"use server";

import { and, eq } from "drizzle-orm";
import { db, deviceTokens, type DeviceToken } from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";
import { getSession } from "@/lib/auth-helper";
import { DeviceRegisterSchema } from "@/lib/schemas/devices";

async function resolveUserId(userId?: string): Promise<string | undefined> {
  if (userId) return userId;
  const session = await getSession();
  return session?.user?.id;
}

/**
 * Registers an APNs device token for the user. Re-registering a token moves
 * it to the current user, so a device that switches accounts stops receiving
 * the previous account's notifications.
 */
export async function registerDeviceAction(
  data: unknown,
  userId?: string
): Promise<{ success: boolean; data?: DeviceToken; error?: string }> {
  try {
    await ensureSchemaInitialized();

    const resolvedUserId = await resolveUserId(userId);
    if (!resolvedUserId) {
      return { success: false, error: "Unauthorized" };
    }

    const parsed = DeviceRegisterSchema.safeParse(data);
    if (!parsed.success) {
      return {
        success: false,
        error: parsed.error.issues
          .map((issue) => `${issue.path.join(".") || "body"}: ${issue.message}`)
          .join("; "),
      };
    }

    const now = new Date();
    const token = parsed.data.token.toLowerCase();
    const [device] = await db
      .insert(deviceTokens)
      .values({ ...parsed.data, token, userId: resolvedUserId, createdAt: now, updatedAt: now })
      .onConflictDoUpdate({
        target: deviceTokens.token,
        set: {
          userId: resolvedUserId,
          platform: parsed.data.platform,
          environment: parsed.data.environment,
          updatedAt: now,
        },
      })
      .returning();

    return { success: true, data: device };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to register device",
    };
  }
}

/** Removes the user's device token, e.g. when they sign out. */
export async function unregisterDeviceAction(
  token: string,
  userId?: string
): Promise<{ success: boolean; error?: string }> {
  try {
    await ensureSchemaInitialized();

    const resolvedUserId = await resolveUserId(userId);
    if (!resolvedUserId) {
      return { success: false, error: "Unauthorized" };
    }

    await db
      .delete(deviceTokens)
      .where(
        and(eq(deviceTokens.token, token.toLowerCase()), eq(deviceTokens.userId, resolvedUserId))
      );
    return { success: true };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to unregister device",
    };
  }
}
