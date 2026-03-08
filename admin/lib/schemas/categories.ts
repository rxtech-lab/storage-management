import { createInsertSchema, createSelectSchema } from "drizzle-zod";
import { z } from "zod";
import { categories } from "@/lib/db/schema";
import { PaginationQueryParams, PaginationInfo } from "./common";
import { ItemResponseSchema } from "./items";

// Base schemas from Drizzle (for internal validation)
export const CategorySelectSchema = createSelectSchema(categories);

// Explicit insert schema for OpenAPI (properly exports)
export const CategoryInsertSchema = z.object({
  name: z.string().describe("Category name"),
  description: z.string().nullable().optional().describe("Category description"),
});

// Explicit update schema for OpenAPI (properly exports)
export const CategoryUpdateSchema = z.object({
  name: z.string().optional().describe("Category name"),
  description: z.string().nullable().optional().describe("Category description"),
});

// Explicit response schema for OpenAPI (properly exports to OpenAPI spec)
export const CategoryResponseSchema = z.object({
  id: z.string().describe("Unique category identifier"),
  userId: z.string().describe("Owner user ID"),
  name: z.string().describe("Category name"),
  description: z.string().nullable().describe("Category description"),
  createdAt: z.coerce.date().describe("Creation timestamp"),
  updatedAt: z.coerce.date().describe("Last update timestamp"),
});

// Detail response with related items
export const CategoryDetailResponseSchema = CategoryResponseSchema.extend({
  items: z.array(ItemResponseSchema).describe("Related items (limited to first 10)"),
  totalItems: z.number().int().describe("Total number of items in this category"),
});

// Query params for categories list
export const CategoriesQueryParams = PaginationQueryParams.extend({
  search: z.string().optional().describe("Search query string"),
});

// Paginated categories response
export const PaginatedCategoriesResponse = z.object({
  data: z.array(CategoryResponseSchema).describe("Array of categories"),
  pagination: PaginationInfo,
});
