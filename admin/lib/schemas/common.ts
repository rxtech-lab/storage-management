import { z } from "zod";

// Pagination query parameters (cursor-based)
export const PaginationQueryParams = z.object({
  cursor: z.string().optional().describe("Base64 encoded cursor for pagination"),
  direction: z
    .enum(["next", "prev"])
    .optional()
    .describe("Pagination direction"),
  limit: z
    .coerce.number()
    .int()
    .min(1)
    .max(100)
    .optional()
    .describe("Items per page (default: 20, max: 100)"),
});

// Pagination response info
export const PaginationInfo = z.object({
  nextCursor: z.string().nullable().describe("Cursor for next page"),
  prevCursor: z.string().nullable().describe("Cursor for previous page"),
  hasNextPage: z
    .boolean()
    .describe("Whether more items exist after current page"),
  hasPrevPage: z
    .boolean()
    .describe("Whether items exist before current page"),
});

// Generic error response
export const ErrorResponse = z.object({
  error: z.string().describe("Error message"),
});

// Generic success response
export const SuccessResponse = z.object({
  success: z.literal(true).describe("Operation succeeded"),
});

// ID path parameter
export const IdPathParams = z.object({
  id: z.string().describe("Resource ID"),
});

// Search query parameter
export const SearchQueryParams = z.object({
  search: z.string().optional().describe("Search query string"),
});
