import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { db, items, categories, locations, authors } from "@/lib/db";
import { eq, count, and } from "drizzle-orm";

export interface DashboardStatsResponse {
  totalItems: number;
  publicItems: number;
  privateItems: number;
  totalCategories: number;
  totalLocations: number;
  totalAuthors: number;
  recentItems: Array<{
    id: number;
    title: string;
    visibility: "public" | "private";
    categoryName: string | null;
    updatedAt: Date;
  }>;
}

export async function GET(request: NextRequest) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const userId = session.user.id;

  // Run all counts in parallel for better performance
  const [
    totalItemsResult,
    publicItemsResult,
    privateItemsResult,
    totalCategoriesResult,
    totalLocationsResult,
    totalAuthorsResult,
    recentItemsResult,
  ] = await Promise.all([
    // Total items count
    db
      .select({ count: count() })
      .from(items)
      .where(eq(items.userId, userId)),

    // Public items count
    db
      .select({ count: count() })
      .from(items)
      .where(and(eq(items.userId, userId), eq(items.visibility, "public"))),

    // Private items count
    db
      .select({ count: count() })
      .from(items)
      .where(and(eq(items.userId, userId), eq(items.visibility, "private"))),

    // Total categories count
    db
      .select({ count: count() })
      .from(categories)
      .where(eq(categories.userId, userId)),

    // Total locations count
    db
      .select({ count: count() })
      .from(locations)
      .where(eq(locations.userId, userId)),

    // Total authors count
    db
      .select({ count: count() })
      .from(authors)
      .where(eq(authors.userId, userId)),

    // Recent items (last 5)
    db.query.items.findMany({
      where: eq(items.userId, userId),
      orderBy: (items, { desc }) => [desc(items.updatedAt)],
      limit: 5,
      with: {
        category: true,
      },
    }),
  ]);

  const response: DashboardStatsResponse = {
    totalItems: totalItemsResult[0]?.count ?? 0,
    publicItems: publicItemsResult[0]?.count ?? 0,
    privateItems: privateItemsResult[0]?.count ?? 0,
    totalCategories: totalCategoriesResult[0]?.count ?? 0,
    totalLocations: totalLocationsResult[0]?.count ?? 0,
    totalAuthors: totalAuthorsResult[0]?.count ?? 0,
    recentItems: recentItemsResult.map((item) => ({
      id: item.id,
      title: item.title,
      visibility: item.visibility,
      categoryName: item.category?.name ?? null,
      updatedAt: item.updatedAt,
    })),
  };

  return NextResponse.json(response);
}
