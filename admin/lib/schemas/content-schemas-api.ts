import { z } from "zod";

// Content schema definition (predefined schemas for content types)
export const ContentSchemaDefinitionSchema = z.object({
  type: z.enum(["file", "image", "video"]).describe("Content type"),
  schema: z.record(z.unknown()).describe("JSON Schema for the content type"),
});

// Response for content schemas endpoint
export const ContentSchemasResponseSchema = z.array(ContentSchemaDefinitionSchema);
