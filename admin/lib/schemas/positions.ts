import { createInsertSchema, createSelectSchema } from "drizzle-zod";
import { z } from "zod";
import { positions } from "@/lib/db/schema";

// Base schemas from Drizzle (for internal validation)
export const PositionSelectSchema = createSelectSchema(positions);

// Explicit insert schema for OpenAPI (properly exports)
export const PositionInsertSchema = z.object({
  itemId: z.number().int().describe("Associated item ID"),
  positionSchemaId: z.number().int().describe("Position schema ID"),
  data: z.record(z.unknown()).describe("Position data"),
});

// Explicit update schema for OpenAPI (properly exports)
export const PositionUpdateSchema = z.object({
  itemId: z.number().int().optional().describe("Associated item ID"),
  positionSchemaId: z.number().int().optional().describe("Position schema ID"),
  data: z.record(z.unknown()).optional().describe("Position data"),
});

// Explicit response schema for OpenAPI (properly exports to OpenAPI spec)
export const PositionResponseSchema = z.object({
  id: z.number().int().describe("Unique position identifier"),
  userId: z.string().describe("Owner user ID"),
  itemId: z.number().int().describe("Associated item ID"),
  positionSchemaId: z.number().int().describe("Position schema ID"),
  data: z.record(z.unknown()).describe("Position data"),
  createdAt: z.coerce.date().describe("Creation timestamp"),
  updatedAt: z.coerce.date().describe("Last update timestamp"),
  positionSchema: z
    .object({
      id: z.number().int(),
      name: z.string(),
      schema: z.record(z.unknown()),
    })
    .nullable()
    .describe("Associated position schema details"),
});

// Array of positions response
export const PositionsListResponse = z.array(PositionResponseSchema);
