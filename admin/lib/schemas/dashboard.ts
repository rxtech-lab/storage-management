import { z } from "zod";

// Simplified schema for recent items in dashboard (subset of full item)
export const DashboardRecentItemSchema = z.object({
  id: z.number().int().describe("Item identifier"),
  title: z.string().describe("Item title"),
  visibility: z.enum(["publicAccess", "privateAccess"]).describe("Item visibility"),
  categoryName: z.string().nullable().describe("Category name if assigned"),
  updatedAt: z.string().datetime().describe("Last updated timestamp"),
});

// Dashboard statistics response
export const DashboardStatsResponseSchema = z.object({
  totalItems: z.number().int().describe("Total number of items"),
  publicItems: z.number().int().describe("Number of public items"),
  privateItems: z.number().int().describe("Number of private items"),
  totalCategories: z.number().int().describe("Total number of categories"),
  totalLocations: z.number().int().describe("Total number of locations"),
  totalAuthors: z.number().int().describe("Total number of authors"),
  recentItems: z.array(DashboardRecentItemSchema).describe("Recently updated items"),
});
