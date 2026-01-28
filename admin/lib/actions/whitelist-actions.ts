"use server";

import { revalidatePath } from "next/cache";
import { eq, and } from "drizzle-orm";
import { db, itemWhitelists, type ItemWhitelist, type NewItemWhitelist } from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";

export async function getItemWhitelist(itemId: number): Promise<ItemWhitelist[]> {
  await ensureSchemaInitialized();
  return db
    .select()
    .from(itemWhitelists)
    .where(eq(itemWhitelists.itemId, itemId))
    .orderBy(itemWhitelists.email);
}

export async function isEmailWhitelisted(itemId: number, email: string): Promise<boolean> {
  const results = await db
    .select()
    .from(itemWhitelists)
    .where(
      and(
        eq(itemWhitelists.itemId, itemId),
        eq(itemWhitelists.email, email.toLowerCase())
      )
    )
    .limit(1);
  return results.length > 0;
}

export async function addToWhitelistAction(
  data: Omit<NewItemWhitelist, "id" | "createdAt">
): Promise<{ success: boolean; data?: ItemWhitelist; error?: string }> {
  try {
    // Normalize email to lowercase
    const normalizedData = {
      ...data,
      email: data.email.toLowerCase(),
    };

    // Check if already exists
    const existing = await db
      .select()
      .from(itemWhitelists)
      .where(
        and(
          eq(itemWhitelists.itemId, normalizedData.itemId),
          eq(itemWhitelists.email, normalizedData.email)
        )
      )
      .limit(1);

    if (existing.length > 0) {
      return { success: true, data: existing[0] };
    }

    const result = await db.insert(itemWhitelists).values(normalizedData).returning();
    revalidatePath(`/items/${data.itemId}`);
    return { success: true, data: result[0] };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to add to whitelist",
    };
  }
}

export async function removeFromWhitelistAction(
  id: number
): Promise<{ success: boolean; error?: string }> {
  try {
    const whitelist = await db
      .select({ itemId: itemWhitelists.itemId })
      .from(itemWhitelists)
      .where(eq(itemWhitelists.id, id))
      .limit(1);

    await db.delete(itemWhitelists).where(eq(itemWhitelists.id, id));

    if (whitelist[0]) {
      revalidatePath(`/items/${whitelist[0].itemId}`);
    }
    return { success: true };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to remove from whitelist",
    };
  }
}

export async function bulkAddToWhitelistAction(
  itemId: number,
  emails: string[]
): Promise<{ success: boolean; added: number; error?: string }> {
  try {
    let addedCount = 0;

    for (const email of emails) {
      const normalizedEmail = email.toLowerCase().trim();
      if (!normalizedEmail) continue;

      const existing = await db
        .select()
        .from(itemWhitelists)
        .where(
          and(
            eq(itemWhitelists.itemId, itemId),
            eq(itemWhitelists.email, normalizedEmail)
          )
        )
        .limit(1);

      if (existing.length === 0) {
        await db.insert(itemWhitelists).values({
          itemId,
          email: normalizedEmail,
        });
        addedCount++;
      }
    }

    revalidatePath(`/items/${itemId}`);
    return { success: true, added: addedCount };
  } catch (error) {
    return {
      success: false,
      added: 0,
      error: error instanceof Error ? error.message : "Failed to bulk add to whitelist",
    };
  }
}
