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
  fileId: z.number().int().describe("Unique file identifier"),
  key: z.string().describe("S3 object key"),
  expiresAt: z.string().describe("Expiration timestamp of the presigned URL"),
});
