import { createInsertSchema, createSelectSchema } from "drizzle-zod";
import { z } from "zod";
import { positionSchemas } from "@/lib/db/schema";
import { PaginationQueryParams, PaginationInfo } from "./common";

// Base schemas from Drizzle (for internal validation)
export const PositionSchemaSelectSchema = createSelectSchema(positionSchemas);

// Explicit insert schema for OpenAPI (properly exports)
export const PositionSchemaInsertSchema = z.object({
  name: z.string().describe("Schema name"),
  schema: z.record(z.unknown()).describe("JSON Schema definition"),
});

// Explicit update schema for OpenAPI (properly exports)
export const PositionSchemaUpdateSchema = z.object({
  name: z.string().optional().describe("Schema name"),
  schema: z.record(z.unknown()).optional().describe("JSON Schema definition"),
});

// Explicit response schema for OpenAPI (properly exports to OpenAPI spec)
export const PositionSchemaResponseSchema = z.object({
  id: z.number().int().describe("Unique position schema identifier"),
  userId: z.string().describe("Owner user ID"),
  name: z.string().describe("Schema name"),
  schema: z.record(z.unknown()).describe("JSON Schema definition"),
  createdAt: z.coerce.date().describe("Creation timestamp"),
  updatedAt: z.coerce.date().describe("Last update timestamp"),
});

// Query params for position schemas list
export const PositionSchemasQueryParams = PaginationQueryParams.extend({
  search: z.string().optional().describe("Search query string"),
});

// Paginated position schemas response
export const PaginatedPositionSchemasResponse = z.object({
  data: z.array(PositionSchemaResponseSchema).describe("Array of position schemas"),
  pagination: PaginationInfo,
});
