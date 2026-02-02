import { createInsertSchema, createSelectSchema } from "drizzle-zod";
import { z } from "zod";
import { categories } from "@/lib/db/schema";
import { PaginationQueryParams, PaginationInfo } from "./common";

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
  id: z.number().int().describe("Unique category identifier"),
  userId: z.string().describe("Owner user ID"),
  name: z.string().describe("Category name"),
  description: z.string().nullable().describe("Category description"),
  createdAt: z.coerce.date().describe("Creation timestamp"),
  updatedAt: z.coerce.date().describe("Last update timestamp"),
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
