"use server";

import { revalidatePath } from "next/cache";
import { eq, desc, sum } from "drizzle-orm";
import { db, stockHistories, items, type StockHistory, type NewStockHistory } from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";
import { getSession } from "@/lib/auth-helper";

export async function getItemStockHistory(itemId: number): Promise<StockHistory[]> {
  await ensureSchemaInitialized();
  return db
    .select()
    .from(stockHistories)
    .where(eq(stockHistories.itemId, itemId))
    .orderBy(desc(stockHistories.createdAt));
}

export async function getItemQuantity(itemId: number): Promise<number> {
  await ensureSchemaInitialized();
  const result = await db
    .select({ total: sum(stockHistories.quantity) })
    .from(stockHistories)
    .where(eq(stockHistories.itemId, itemId));

  return Number(result[0]?.total ?? 0);
}

export async function createStockHistoryAction(
  data: Omit<NewStockHistory, "id" | "userId" | "createdAt">,
  userId?: string
): Promise<{ success: boolean; data?: StockHistory; error?: string }> {
  try {
    let resolvedUserId = userId;
    if (!resolvedUserId) {
      const session = await getSession();
      if (!session?.user?.id) {
        return { success: false, error: "Unauthorized" };
      }
      resolvedUserId = session.user.id;
    }

    // Verify user owns the parent item
    const parentItem = await db
      .select({ userId: items.userId })
      .from(items)
      .where(eq(items.id, data.itemId))
      .limit(1);

    if (!parentItem[0] || parentItem[0].userId !== resolvedUserId) {
      return { success: false, error: "Permission denied" };
    }

    const result = await db.insert(stockHistories).values({
      ...data,
      userId: resolvedUserId,
    }).returning();

    revalidatePath(`/items/${data.itemId}`);
    return { success: true, data: result[0] };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to create stock history entry",
    };
  }
}

export async function deleteStockHistoryAction(
  id: number,
  userId?: string
): Promise<{ success: boolean; error?: string }> {
  try {
    let resolvedUserId = userId;
    if (!resolvedUserId) {
      const session = await getSession();
      if (!session?.user?.id) {
        return { success: false, error: "Unauthorized" };
      }
      resolvedUserId = session.user.id;
    }

    // Verify ownership
    const existing = await db
      .select({ userId: stockHistories.userId, itemId: stockHistories.itemId })
      .from(stockHistories)
      .where(eq(stockHistories.id, id))
      .limit(1);

    if (!existing[0] || existing[0].userId !== resolvedUserId) {
      return { success: false, error: "Permission denied" };
    }

    await db.delete(stockHistories).where(eq(stockHistories.id, id));

    revalidatePath(`/items/${existing[0].itemId}`);
    return { success: true };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to delete stock history entry",
    };
  }
}
