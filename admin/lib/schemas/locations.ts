import { createInsertSchema, createSelectSchema } from "drizzle-zod";
import { z } from "zod";
import { locations } from "@/lib/db/schema";
import { PaginationQueryParams, PaginationInfo } from "./common";

// Base schemas from Drizzle (for internal validation)
export const LocationSelectSchema = createSelectSchema(locations);

// Explicit insert schema for OpenAPI (properly exports)
export const LocationInsertSchema = z.object({
  title: z.string().describe("Location title"),
  latitude: z.number().describe("Latitude coordinate"),
  longitude: z.number().describe("Longitude coordinate"),
});

// Explicit update schema for OpenAPI (properly exports)
export const LocationUpdateSchema = z.object({
  title: z.string().optional().describe("Location title"),
  latitude: z.number().optional().describe("Latitude coordinate"),
  longitude: z.number().optional().describe("Longitude coordinate"),
});

// Explicit response schema for OpenAPI (properly exports to OpenAPI spec)
export const LocationResponseSchema = z.object({
  id: z.number().int().describe("Unique location identifier"),
  userId: z.string().describe("Owner user ID"),
  title: z.string().describe("Location title"),
  latitude: z.number().describe("Latitude coordinate"),
  longitude: z.number().describe("Longitude coordinate"),
  createdAt: z.coerce.date().describe("Creation timestamp"),
  updatedAt: z.coerce.date().describe("Last update timestamp"),
});

// Query params for locations list
export const LocationsQueryParams = PaginationQueryParams.extend({
  search: z.string().optional().describe("Search query string"),
});

// Paginated locations response
export const PaginatedLocationsResponse = z.object({
  data: z.array(LocationResponseSchema).describe("Array of locations"),
  pagination: PaginationInfo,
});
