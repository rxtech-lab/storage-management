import { z } from "zod";
import { ItemResponseSchema } from "./items";

// Dashboard statistics response
export const DashboardStatsResponseSchema = z.object({
  totalItems: z.number().int().describe("Total number of items"),
  publicItems: z.number().int().describe("Number of public items"),
  privateItems: z.number().int().describe("Number of private items"),
  totalCategories: z.number().int().describe("Total number of categories"),
  totalLocations: z.number().int().describe("Total number of locations"),
  totalAuthors: z.number().int().describe("Total number of authors"),
  recentItems: z.array(ItemResponseSchema).describe("Recently created items"),
});
