import { z } from "zod";
import { PaginationQueryParams, PaginationInfo } from "./common";

// Explicit insert schema for OpenAPI
export const TagInsertSchema = z.object({
  title: z.string().describe("Tag title"),
  color: z.string().describe("Tag color as hex string (e.g. #FF5733)"),
});

// Explicit update schema for OpenAPI
export const TagUpdateSchema = z.object({
  title: z.string().optional().describe("Tag title"),
  color: z.string().optional().describe("Tag color as hex string (e.g. #FF5733)"),
});

// Explicit response schema for OpenAPI
export const TagResponseSchema = z.object({
  id: z.string().describe("Unique tag identifier"),
  userId: z.string().describe("Owner user ID"),
  title: z.string().describe("Tag title"),
  color: z.string().describe("Tag color as hex string (e.g. #FF5733)"),
  createdAt: z.coerce.date().describe("Creation timestamp"),
  updatedAt: z.coerce.date().describe("Last update timestamp"),
});

// Tag reference for embedding in item responses
export const TagRefSchema = z.object({
  id: z.string().describe("Tag ID"),
  title: z.string().describe("Tag title"),
  color: z.string().describe("Tag color as hex string"),
});

// Request to add a tag to an item
export const ItemTagInsertSchema = z.object({
  tagId: z.string().describe("Tag ID to add to the item"),
});

// Item tag response (the junction record)
export const ItemTagResponseSchema = z.object({
  id: z.string().describe("Item-tag relation ID"),
  itemId: z.string().describe("Item ID"),
  tagId: z.string().describe("Tag ID"),
  tag: TagRefSchema.describe("Tag details"),
  createdAt: z.coerce.date().describe("Creation timestamp"),
});

// Path params for item tag routes
export const ItemTagPathParams = z.object({
  id: z.string().describe("Item ID"),
  tagId: z.string().describe("Tag ID"),
});

// List of tag refs for item tags response
export const ItemTagsListResponse = z.array(TagRefSchema);

// Query params for tags list
export const TagsQueryParams = PaginationQueryParams.extend({
  search: z.string().optional().describe("Search query string"),
});

// Paginated tags response
export const PaginatedTagsResponse = z.object({
  data: z.array(TagResponseSchema).describe("Array of tags"),
  pagination: PaginationInfo,
});
