"use server";

import { and, eq } from "drizzle-orm";
import { db, liveActivityTokens, type LiveActivityToken } from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";
import { getSession } from "@/lib/auth-helper";
import { LiveActivityTokenRegisterSchema } from "@/lib/schemas/live-activities";

async function resolveUserId(userId?: string): Promise<string | undefined> {
  if (userId) return userId;
  const session = await getSession();
  return session?.user?.id;
}

/**
 * Registers an ActivityKit push token for the user. Re-registering a token
 * moves it to the current user, like device tokens.
 */
export async function registerLiveActivityTokenAction(
  data: unknown,
  userId?: string
): Promise<{ success: boolean; data?: LiveActivityToken; error?: string }> {
  try {
    await ensureSchemaInitialized();

    const resolvedUserId = await resolveUserId(userId);
    if (!resolvedUserId) {
      return { success: false, error: "Unauthorized" };
    }

    const parsed = LiveActivityTokenRegisterSchema.safeParse(data);
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
    const [row] = await db
      .insert(liveActivityTokens)
      .values({
        token,
        userId: resolvedUserId,
        kind: parsed.data.kind,
        environment: parsed.data.environment,
        createdAt: now,
        updatedAt: now,
      })
      .onConflictDoUpdate({
        target: liveActivityTokens.token,
        set: {
          userId: resolvedUserId,
          kind: parsed.data.kind,
          environment: parsed.data.environment,
          lastPushedAt: null,
          updatedAt: now,
        },
      })
      .returning();

    return { success: true, data: row };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to register Live Activity token",
    };
  }
}

/** Removes the user's ActivityKit push token, e.g. when they sign out. */
export async function unregisterLiveActivityTokenAction(
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
      .delete(liveActivityTokens)
      .where(
        and(
          eq(liveActivityTokens.token, token.toLowerCase()),
          eq(liveActivityTokens.userId, resolvedUserId)
        )
      );
    return { success: true };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to unregister Live Activity token",
    };
  }
}
