import { z } from "zod";

// Simplified schema for recent items in dashboard (subset of full item)
export const DashboardRecentItemSchema = z.object({
  id: z.string().describe("Item identifier"),
  title: z.string().describe("Item title"),
  visibility: z.enum(["publicAccess", "privateAccess"]).describe("Item visibility"),
  categoryName: z.string().nullable().describe("Category name if assigned"),
  updatedAt: z.string().datetime().describe("Last updated timestamp"),
});

// Chart data point for dashboard charts
export const DashboardChartDataPointSchema = z.object({
  label: z.string().describe("Label for the data point"),
  value: z.number().int().describe("Count value"),
  color: z.string().optional().describe("Optional color (e.g. for tags)"),
});

// Dashboard charts response with aggregated data
export const DashboardChartsResponseSchema = z.object({
  itemsByLocation: z
    .array(DashboardChartDataPointSchema)
    .describe("Top 5 locations by item count"),
  itemsByTag: z
    .array(DashboardChartDataPointSchema)
    .describe("Top 5 tags by item count"),
  itemsByMonth: z
    .array(DashboardChartDataPointSchema)
    .describe("Items grouped by month (most recent 5)"),
  itemsByCategory: z
    .array(DashboardChartDataPointSchema)
    .describe("Top 5 categories by item count"),
  itemsByVisibility: z
    .array(DashboardChartDataPointSchema)
    .describe("Items grouped by visibility"),
  itemsByAuthor: z
    .array(DashboardChartDataPointSchema)
    .describe("Top 5 authors by item count"),
});

// Dashboard statistics response
export const DashboardStatsResponseSchema = z.object({
  totalItems: z.number().int().describe("Total number of items"),
  publicItems: z.number().int().describe("Number of public items"),
  privateItems: z.number().int().describe("Number of private items"),
  totalCategories: z.number().int().describe("Total number of categories"),
  totalLocations: z.number().int().describe("Total number of locations"),
  totalAuthors: z.number().int().describe("Total number of authors"),
  totalPositionSchemas: z
    .number()
    .int()
    .describe("Total number of position schemas"),
  recentItems: z.array(DashboardRecentItemSchema).describe("Recently updated items"),
});
