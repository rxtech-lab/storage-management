import { z } from "zod";

// Explicit response schema for OpenAPI (avoids drizzle-zod compatibility issues)
export const WhitelistResponseSchema = z.object({
  id: z.number().int().describe("Unique whitelist entry identifier"),
  itemId: z.number().int().describe("Associated item ID"),
  email: z.string().describe("Whitelisted email address"),
  createdAt: z.coerce.date().describe("Creation timestamp"),
});

// Request to add email to whitelist
export const WhitelistAddRequestSchema = z.object({
  email: z.string().email().describe("Email address to whitelist"),
});

// Request to remove email from whitelist
export const WhitelistRemoveRequestSchema = z.object({
  whitelistId: z.number().int().describe("Whitelist entry ID to remove"),
});

// Array of whitelist entries response
export const WhitelistListResponse = z.array(WhitelistResponseSchema);
