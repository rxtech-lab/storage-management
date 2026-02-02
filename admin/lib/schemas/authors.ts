import { createInsertSchema, createSelectSchema } from "drizzle-zod";
import { z } from "zod";
import { authors } from "@/lib/db/schema";
import { PaginationQueryParams, PaginationInfo } from "./common";

// Base schemas from Drizzle (for internal validation)
export const AuthorSelectSchema = createSelectSchema(authors);

// Explicit insert schema for OpenAPI (properly exports)
export const AuthorInsertSchema = z.object({
  name: z.string().describe("Author name"),
  bio: z.string().nullable().optional().describe("Author biography"),
});

// Explicit update schema for OpenAPI (properly exports)
export const AuthorUpdateSchema = z.object({
  name: z.string().optional().describe("Author name"),
  bio: z.string().nullable().optional().describe("Author biography"),
});

// Explicit response schema for OpenAPI (properly exports to OpenAPI spec)
export const AuthorResponseSchema = z.object({
  id: z.number().int().describe("Unique author identifier"),
  userId: z.string().describe("Owner user ID"),
  name: z.string().describe("Author name"),
  bio: z.string().nullable().describe("Author biography"),
  createdAt: z.coerce.date().describe("Creation timestamp"),
  updatedAt: z.coerce.date().describe("Last update timestamp"),
});

// Query params for authors list
export const AuthorsQueryParams = PaginationQueryParams.extend({
  search: z.string().optional().describe("Search query string"),
});

// Paginated authors response
export const PaginatedAuthorsResponse = z.object({
  data: z.array(AuthorResponseSchema).describe("Array of authors"),
  pagination: PaginationInfo,
});
