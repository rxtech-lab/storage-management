import { z } from "zod";

// Response schema for account deletion status
export const AccountDeletionResponseSchema = z.object({
  id: z.number().int().describe("Unique deletion request identifier"),
  userId: z.string().describe("User ID"),
  userEmail: z.string().nullable().describe("User email"),
  scheduledAt: z.coerce.date().describe("Scheduled deletion timestamp"),
  status: z
    .enum(["pending", "completed", "cancelled"])
    .describe("Deletion status"),
  createdAt: z.coerce.date().describe("Creation timestamp"),
  updatedAt: z.coerce.date().describe("Last update timestamp"),
});

// Response for deletion request
export const AccountDeletionRequestResponseSchema = z.object({
  message: z.string().describe("Status message"),
  deletion: AccountDeletionResponseSchema.describe("Deletion record"),
});

// Response for cancellation
export const AccountDeletionCancelResponseSchema = z.object({
  message: z.string().describe("Status message"),
});

// Response for status check (nullable)
export const AccountDeletionStatusResponseSchema = z.object({
  pending: z.boolean().describe("Whether account has a pending deletion"),
  deletion: AccountDeletionResponseSchema.nullable().describe(
    "Deletion record if pending"
  ),
});
