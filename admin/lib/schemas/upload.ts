import { z } from "zod";

// Request to get presigned URL for upload
export const PresignedUploadRequestSchema = z.object({
  filename: z.string().min(1).describe("Name of the file to upload"),
  contentType: z.string().min(1).describe("MIME type of the file"),
  size: z.number().int().positive().optional().describe("File size in bytes"),
});

// Response with presigned URL details
export const PresignedUploadResponseSchema = z.object({
  uploadUrl: z.string().url().describe("Presigned URL for upload"),
  publicUrl: z.string().url().describe("Public URL where the file will be accessible after upload"),
  fileId: z.string().describe("Unique file identifier"),
  key: z.string().describe("S3 object key"),
  expiresAt: z.string().describe("Expiration timestamp of the presigned URL"),
});

// Content preview presigned upload - request item
export const ContentPreviewUploadItemSchema = z.object({
  filename: z.string().min(1).describe("Name of the file"),
  type: z.enum(["image", "video"]).describe("Content type: image or video"),
  title: z.string().min(1).describe("Content title"),
  description: z.string().optional().describe("Content description"),
  mime_type: z.string().min(1).describe("MIME type of the file"),
  size: z.number().int().nonnegative().describe("File size in bytes"),
  file_path: z.string().min(1).describe("S3 file path/key of the original file"),
  video_length: z.number().nonnegative().optional().describe("Video length in seconds (required for video type)"),
});

// Content preview presigned upload - request (array)
export const ContentPreviewUploadRequestSchema = z.array(ContentPreviewUploadItemSchema)
  .describe("Array of content items to generate preview upload URLs for");

// Content preview presigned upload - response item
export const ContentPreviewUploadResponseItemSchema = z.object({
  id: z.string().describe("File record ID for the preview"),
  imageUrl: z.string().describe("Presigned PUT URL for preview image upload"),
  videoUrl: z.string().optional().describe("Presigned PUT URL for preview video upload (only for video type)"),
});

// Content preview presigned upload - response (array)
export const ContentPreviewUploadResponseSchema = z.array(ContentPreviewUploadResponseItemSchema)
  .describe("Array of presigned upload URLs for content previews");
