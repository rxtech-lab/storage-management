"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { eq } from "drizzle-orm";
import { db, locations, type Location, type NewLocation } from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";

export async function getLocations(): Promise<Location[]> {
  await ensureSchemaInitialized();
  return db.select().from(locations).orderBy(locations.title);
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
  data: Omit<NewLocation, "id" | "createdAt" | "updatedAt">
): Promise<{ success: boolean; data?: Location; error?: string }> {
  try {
    const now = new Date();
    const result = await db
      .insert(locations)
      .values({
        ...data,
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
  data: Partial<Omit<NewLocation, "id" | "createdAt" | "updatedAt">>
): Promise<{ success: boolean; data?: Location; error?: string }> {
  try {
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
  id: number
): Promise<{ success: boolean; error?: string }> {
  try {
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
  data: Omit<NewLocation, "id" | "createdAt" | "updatedAt">
) {
  const result = await createLocationAction(data);
  if (result.success) {
    redirect("/locations");
  }
  return result;
}

export async function deleteLocationAndRedirect(id: number) {
  const result = await deleteLocationAction(id);
  if (result.success) {
    redirect("/locations");
  }
  return result;
}

export async function deleteLocationFormAction(id: number): Promise<void> {
  await deleteLocationAction(id);
  revalidatePath("/locations");
}
