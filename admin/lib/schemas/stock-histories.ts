import { z } from "zod";

// Insert schema for creating stock history entries
export const StockHistoryInsertSchema = z.object({
  itemId: z.number().int().describe("Associated item ID"),
  quantity: z.number().int().describe("Quantity change (positive for additions, negative for removals)"),
  note: z.string().nullable().optional().describe("Optional note for this stock change"),
});

// Response schema for stock history entries
export const StockHistoryResponseSchema = z.object({
  id: z.number().int().describe("Unique stock history entry identifier"),
  userId: z.string().describe("Owner user ID"),
  itemId: z.number().int().describe("Associated item ID"),
  quantity: z.number().int().describe("Quantity change"),
  note: z.string().nullable().describe("Optional note"),
  createdAt: z.coerce.date().describe("Creation timestamp"),
});

// Array of stock history entries
export const StockHistoriesListResponse = z.array(StockHistoryResponseSchema);
