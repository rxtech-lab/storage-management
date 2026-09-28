import { z } from "zod";
import { PaginationQueryParams, PaginationInfo } from "./common";

export const IsoJobKind = z
  .enum(["generate", "burn", "upload"])
  .describe(
    "generate writes ISO files from a folder; burn writes ISO files to discs; upload uploads content files to an item"
  );

export const IsoJobStatus = z
  .enum(["running", "completed", "failed", "cancelled", "stopped"])
  .describe("Lifecycle state of the job");

export const IsoJobTaskSection = z
  .enum(["iso", "drive", "file"])
  .describe("iso rows track one ISO file; drive rows track one disc drive; file rows track one uploaded file");

// One progress row as reported by the CLI
export const IsoJobTaskInputSchema = z.object({
  section: IsoJobTaskSection,
  name: z.string().min(1).max(512).describe("ISO file name, drive name or uploaded file name"),
  status: z
    .string()
    .min(1)
    .max(64)
    .describe("Row state, e.g. queued, copying, done, waiting, burning, verifying, uploading"),
  detail: z.string().max(1024).nullable().optional().describe("Human-readable detail line"),
  progress: z.number().min(0).max(1).describe("Fraction done, 0 to 1"),
  doneBytes: z.number().int().min(0).describe("Bytes done in the current phase"),
  totalBytes: z.number().int().min(0).describe("Bytes in the current phase"),
  error: z.string().max(2048).nullable().optional().describe("Last error for this row"),
});

// Full job snapshot sent by the CLI; replaces the stored job and its rows
export const IsoJobUpsertSchema = z.object({
  kind: IsoJobKind,
  title: z.string().min(1).max(512).describe("Job title, e.g. the ISO name"),
  status: IsoJobStatus,
  hostName: z.string().max(255).nullable().optional().describe("Machine running the job"),
  progress: z.number().min(0).max(1).describe("Overall fraction done, 0 to 1"),
  doneCount: z.number().int().min(0).describe("ISOs written, discs burned or files uploaded"),
  totalCount: z.number().int().min(0).describe("ISOs to write, discs to burn or files to upload"),
  doneBytes: z.number().int().min(0).describe("Bytes written so far"),
  totalBytes: z.number().int().min(0).describe("Bytes to write in total"),
  message: z.string().max(1024).nullable().optional().describe("Current state, e.g. waiting for a disc"),
  error: z.string().max(2048).nullable().optional().describe("Why the job failed"),
  startedAt: z.coerce.date().describe("When the job started"),
  finishedAt: z.coerce.date().nullable().optional().describe("When the job ended"),
  tasks: z.array(IsoJobTaskInputSchema).max(2000).describe("Progress rows, in display order"),
});

export const IsoJobTaskResponseSchema = IsoJobTaskInputSchema.extend({
  id: z.string().describe("Row ID"),
  position: z.number().int().describe("Display order within the job"),
  detail: z.string().nullable().describe("Human-readable detail line"),
  error: z.string().nullable().describe("Last error for this row"),
});

export const IsoJobResponseSchema = z.object({
  id: z.string().describe("Job ID chosen by the CLI"),
  userId: z.string().describe("Owner user ID"),
  kind: IsoJobKind,
  title: z.string().describe("Job title"),
  status: IsoJobStatus,
  hostName: z.string().nullable().describe("Machine running the job"),
  progress: z.number().describe("Overall fraction done, 0 to 1"),
  doneCount: z.number().int().describe("ISOs written, discs burned or files uploaded"),
  totalCount: z.number().int().describe("ISOs to write, discs to burn or files to upload"),
  doneBytes: z.number().int().describe("Bytes written so far"),
  totalBytes: z.number().int().describe("Bytes to write in total"),
  message: z.string().nullable().describe("Current state"),
  error: z.string().nullable().describe("Why the job failed"),
  startedAt: z.coerce.date().describe("When the job started"),
  finishedAt: z.coerce.date().nullable().describe("When the job ended"),
  createdAt: z.coerce.date().describe("Creation timestamp"),
  updatedAt: z.coerce.date().describe("Last progress report"),
});

export const IsoJobDetailResponseSchema = IsoJobResponseSchema.extend({
  tasks: z.array(IsoJobTaskResponseSchema).describe("Progress rows, in display order"),
});

// Enums are inlined so the OpenAPI generator emits typed query parameters
export const IsoJobsQueryParams = PaginationQueryParams.extend({
  kind: z.enum(["generate", "burn", "upload"]).optional().describe("Only jobs of this kind"),
  status: z
    .enum(["running", "completed", "failed", "cancelled", "stopped"])
    .optional()
    .describe("Only jobs in this state"),
});

export const PaginatedIsoJobsResponse = z.object({
  data: z.array(IsoJobResponseSchema).describe("Array of ISO jobs, most recently updated first"),
  pagination: PaginationInfo,
});

export type IsoJobUpsert = z.infer<typeof IsoJobUpsertSchema>;
