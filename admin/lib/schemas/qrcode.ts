import { z } from "zod";

/**
 * Request body for QR code scan endpoint
 */
export const QrCodeScanRequestSchema = z.object({
  qrcontent: z.string().min(1).describe("QR code content to scan"),
});

/**
 * Type of resource found from QR code
 */
export const QrCodeTypeSchema = z.enum(["item"]);

/**
 * Response from QR code scan endpoint
 */
export const QrCodeScanResponseSchema = z.object({
  type: QrCodeTypeSchema.describe("Type of resource found"),
  url: z.string().url().describe("Full API URL to the resource"),
});

export type QrCodeScanRequest = z.infer<typeof QrCodeScanRequestSchema>;
export type QrCodeScanResponse = z.infer<typeof QrCodeScanResponseSchema>;
export type QrCodeType = z.infer<typeof QrCodeTypeSchema>;
