import { createSelectSchema } from "drizzle-zod";
import { z } from "zod";
import { itemWhitelists } from "@/lib/db/schema";

// Base schemas from Drizzle
export const WhitelistSelectSchema = createSelectSchema(itemWhitelists, {
  id: (schema) => schema.describe("Unique whitelist entry identifier"),
  itemId: (schema) => schema.describe("Associated item ID"),
  email: (schema) => schema.describe("Whitelisted email address"),
  createdAt: (schema) => schema.describe("Creation timestamp"),
});

// Request to add email to whitelist
export const WhitelistAddRequestSchema = z.object({
  email: z.string().email().describe("Email address to whitelist"),
});

// Request to remove email from whitelist
export const WhitelistRemoveRequestSchema = z.object({
  whitelistId: z.number().int().describe("Whitelist entry ID to remove"),
});

// Response schema
export const WhitelistResponseSchema = WhitelistSelectSchema;

// Array of whitelist entries response
export const WhitelistListResponse = z.array(WhitelistResponseSchema);
