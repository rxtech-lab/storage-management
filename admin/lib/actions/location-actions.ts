"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { eq, like, and } from "drizzle-orm";
import { db, locations, type Location, type NewLocation } from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";
import { getSession } from "@/lib/auth-helper";

export interface LocationFilters {
  search?: string;
  limit?: number;
}

export async function getLocations(userId?: string, filters?: LocationFilters): Promise<Location[]> {
  await ensureSchemaInitialized();

  const conditions = [];

  if (userId) {
    conditions.push(eq(locations.userId, userId));
  }

  if (filters?.search) {
    conditions.push(like(locations.title, `%${filters.search}%`));
  }

  let query = db.select().from(locations).orderBy(locations.title).$dynamic();

  if (conditions.length > 0) {
    query = query.where(and(...conditions));
  }

  if (filters?.limit) {
    query = query.limit(filters.limit);
  }

  return query;
}

export async function getLocation(id: number): Promise<Location | undefined> {
  await ensureSchemaInitialized();
  const results = await db
    .select()
    .from(locations)
    .where(eq(locations.id, id))
    .limit(1);
  return results[0];
}

export async function createLocationAction(
  data: Omit<NewLocation, "id" | "userId" | "createdAt" | "updatedAt">,
  userId?: string
): Promise<{ success: boolean; data?: Location; error?: string }> {
  try {
    // Get userId from session if not provided
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
      .insert(locations)
      .values({
        ...data,
        userId: resolvedUserId,
        createdAt: now,
        updatedAt: now,
      })
      .returning();
    revalidatePath("/locations");
    return { success: true, data: result[0] };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to create location",
    };
  }
}

export async function updateLocationAction(
  id: number,
  data: Partial<Omit<NewLocation, "id" | "userId" | "createdAt" | "updatedAt">>,
  userId?: string
): Promise<{ success: boolean; data?: Location; error?: string }> {
  try {
    // Get userId from session if not provided
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
      .select({ userId: locations.userId })
      .from(locations)
      .where(eq(locations.id, id))
      .limit(1);

    if (!existing[0] || existing[0].userId !== resolvedUserId) {
      return { success: false, error: "Permission denied" };
    }

    const result = await db
      .update(locations)
      .set({ ...data, updatedAt: new Date() })
      .where(eq(locations.id, id))
      .returning();
    revalidatePath("/locations");
    revalidatePath(`/locations/${id}`);
    return { success: true, data: result[0] };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to update location",
    };
  }
}

export async function deleteLocationAction(
  id: number,
  userId?: string
): Promise<{ success: boolean; error?: string }> {
  try {
    // Get userId from session if not provided
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
      .select({ userId: locations.userId })
      .from(locations)
      .where(eq(locations.id, id))
      .limit(1);

    if (!existing[0] || existing[0].userId !== resolvedUserId) {
      return { success: false, error: "Permission denied" };
    }

    await db.delete(locations).where(eq(locations.id, id));
    revalidatePath("/locations");
    return { success: true };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to delete location",
    };
  }
}

export async function createLocationAndRedirect(
  data: Omit<NewLocation, "id" | "userId" | "createdAt" | "updatedAt">,
  userId?: string
) {
  const result = await createLocationAction(data, userId);
  if (result.success) {
    redirect("/locations");
  }
  return result;
}

export async function deleteLocationAndRedirect(id: number, userId?: string) {
  const result = await deleteLocationAction(id, userId);
  if (result.success) {
    redirect("/locations");
  }
  return result;
}

export async function deleteLocationFormAction(id: number): Promise<void> {
  await deleteLocationAction(id);
  revalidatePath("/locations");
}
