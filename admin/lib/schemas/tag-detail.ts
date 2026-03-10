import { z } from "zod";
import { ItemResponseSchema } from "./items";
import { TagResponseSchema } from "./tags";

// Detail response with related items
// Defined in a separate file to avoid circular dependency (items.ts imports TagRefSchema from tags.ts)
export const TagDetailResponseSchema = TagResponseSchema.extend({
  items: z.array(ItemResponseSchema).describe("Related items (limited to first 10)"),
  totalItems: z.number().int().describe("Total number of items with this tag"),
});
