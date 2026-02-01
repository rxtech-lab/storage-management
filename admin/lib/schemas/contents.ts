import { createInsertSchema, createSelectSchema } from "drizzle-zod";
import { z } from "zod";
import { contents } from "@/lib/db/schema";

// File content data schema
export const FileContentDataSchema = z.object({
  title: z.string().describe("File title"),
  description: z.string().optional().describe("File description"),
  mime_type: z.string().describe("MIME type of the file"),
  size: z.number().describe("File size in bytes"),
  file_path: z.string().describe("S3 file path/key"),
});

// Image content data schema (extends file)
export const ImageContentDataSchema = FileContentDataSchema.extend({
  preview_image_url: z.string().optional().describe("Preview image URL"),
});

// Video content data schema (extends image)
export const VideoContentDataSchema = ImageContentDataSchema.extend({
  video_length: z.number().describe("Video length in seconds"),
  preview_video_url: z.string().optional().describe("Preview video URL"),
});

// Union of all content data types
export const ContentDataSchema = z.union([
  FileContentDataSchema,
  ImageContentDataSchema,
  VideoContentDataSchema,
]);

// Base schemas from Drizzle (for internal validation)
export const ContentSelectSchema = createSelectSchema(contents);

export const ContentInsertSchema = z.object({
  type: z.enum(["file", "image", "video"]).describe("Content type (required)"),
  data: ContentDataSchema.describe("Content metadata (required)"),
});

export const ContentUpdateSchema = z.object({
  type: z.enum(["file", "image", "video"]).optional().describe("Content type"),
  data: ContentDataSchema.optional().describe("Content metadata"),
});

// Explicit response schema for OpenAPI (properly exports to OpenAPI spec)
export const ContentResponseSchema = z.object({
  id: z.number().int().describe("Unique content identifier"),
  itemId: z.number().int().describe("Associated item ID"),
  type: z.enum(["file", "image", "video"]).describe("Content type: file, image, or video"),
  data: z.record(z.unknown()).describe("Content metadata (JSON)"),
  createdAt: z.coerce.date().describe("Creation timestamp"),
  updatedAt: z.coerce.date().describe("Last update timestamp"),
});

// Array of contents response
export const ContentsListResponse = z.array(ContentResponseSchema);
