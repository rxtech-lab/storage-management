import { z } from "zod";

// Insert schema for creating stock history entries
export const StockHistoryInsertSchema = z.object({
  itemId: z.string().describe("Associated item ID"),
  stockId: z
    .string()
    .nullable()
    .optional()
    .describe("Stock placement ID (null or omitted for the item's main placement)"),
  quantity: z.number().int().describe("Quantity change (positive for additions, negative for removals)"),
  note: z.string().nullable().optional().describe("Optional note for this stock change"),
});

// Response schema for stock history entries
export const StockHistoryResponseSchema = z.object({
  id: z.string().describe("Unique stock history entry identifier"),
  userId: z.string().describe("Owner user ID"),
  itemId: z.string().describe("Associated item ID"),
  stockId: z.string().nullable().describe("Stock placement ID (null for the item's main placement)"),
  quantity: z.number().int().describe("Quantity change"),
  note: z.string().nullable().describe("Optional note"),
  createdAt: z.coerce.date().describe("Creation timestamp"),
});

// Array of stock history entries
export const StockHistoriesListResponse = z.array(StockHistoryResponseSchema);
