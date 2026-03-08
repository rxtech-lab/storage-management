import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { db, items, categories, locations, tags, itemTags, authors } from "@/lib/db";
import { eq, count, sql, desc } from "drizzle-orm";
import { DashboardChartsResponseSchema } from "@/lib/schemas/dashboard";

/**
 * Get dashboard chart data
 * @operationId getDashboardCharts
 * @description Returns aggregated chart data for items by location, tag, month, category, and visibility
 * @response DashboardChartsResponseSchema
 * @auth bearer
 * @tag Dashboard
 * @responseSet auth
 * @openapi
 */
export async function GET(request: NextRequest) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const userId = session.user.id;

  const [
    itemsByLocationResult,
    itemsByTagResult,
    itemsByMonthResult,
    itemsByCategoryResult,
    itemsByVisibilityResult,
    itemsByAuthorResult,
  ] = await Promise.all([
    // Top 5 locations by item count
    db
      .select({
        label: locations.title,
        value: count(),
      })
      .from(items)
      .innerJoin(locations, eq(items.locationId, locations.id))
      .where(eq(items.userId, userId))
      .groupBy(locations.title)
      .orderBy(desc(count()))
      .limit(5),

    // Top 5 tags by item count
    db
      .select({
        label: tags.title,
        value: count(),
        color: tags.color,
      })
      .from(itemTags)
      .innerJoin(items, eq(itemTags.itemId, items.id))
      .innerJoin(tags, eq(itemTags.tagId, tags.id))
      .where(eq(items.userId, userId))
      .groupBy(tags.title, tags.color)
      .orderBy(desc(count()))
      .limit(5),

    // Items grouped by month (most recent 5 months)
    db
      .select({
        label: sql<string>`strftime('%Y-%m', datetime(${items.createdAt}, 'unixepoch'))`.as(
          "month"
        ),
        value: count(),
      })
      .from(items)
      .where(eq(items.userId, userId))
      .groupBy(sql`strftime('%Y-%m', datetime(${items.createdAt}, 'unixepoch'))`)
      .orderBy(
        desc(
          sql`strftime('%Y-%m', datetime(${items.createdAt}, 'unixepoch'))`
        )
      )
      .limit(5),

    // Top 5 categories by item count
    db
      .select({
        label: categories.name,
        value: count(),
      })
      .from(items)
      .innerJoin(categories, eq(items.categoryId, categories.id))
      .where(eq(items.userId, userId))
      .groupBy(categories.name)
      .orderBy(desc(count()))
      .limit(5),

    // Items by visibility
    db
      .select({
        label: items.visibility,
        value: count(),
      })
      .from(items)
      .where(eq(items.userId, userId))
      .groupBy(items.visibility),

    // Top 5 authors by item count
    db
      .select({
        label: authors.name,
        value: count(),
      })
      .from(items)
      .innerJoin(authors, eq(items.authorId, authors.id))
      .where(eq(items.userId, userId))
      .groupBy(authors.name)
      .orderBy(desc(count()))
      .limit(5),
  ]);

  // Reverse month results so they are chronological (oldest first)
  const itemsByMonth = [...itemsByMonthResult].reverse();

  // Map visibility labels to human-readable names
  const itemsByVisibility = itemsByVisibilityResult.map((row) => ({
    label: row.label === "publicAccess" ? "Public" : "Private",
    value: row.value,
    color: row.label === "publicAccess" ? "#34C759" : "#FF9500",
  }));

  const responseData = {
    itemsByLocation: itemsByLocationResult.map((row) => ({
      label: row.label,
      value: row.value,
    })),
    itemsByTag: itemsByTagResult.map((row) => ({
      label: row.label,
      value: row.value,
      color: row.color,
    })),
    itemsByMonth,
    itemsByCategory: itemsByCategoryResult.map((row) => ({
      label: row.label,
      value: row.value,
    })),
    itemsByVisibility,
    itemsByAuthor: itemsByAuthorResult.map((row) => ({
      label: row.label,
      value: row.value,
    })),
  };

  const response = DashboardChartsResponseSchema.parse(responseData);

  return NextResponse.json(response);
}
