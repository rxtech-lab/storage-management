import { z } from "zod";
import { ItemAIResponseSchema } from "./item-ai";

export const BarcodeLookupRequestSchema = z.object({
  barcode: z.string().trim().min(1).max(2000),
  inventory: z.boolean().default(true).describe("Resolve an existing inventory item before external lookup"),
});

export const BarcodeLookupResponseSchema = z.object({
  barcode: z.string(),
  itemUrl: z.string().url().nullable(),
  result: ItemAIResponseSchema.nullable(),
});
