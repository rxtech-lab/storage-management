"use server";

import { revalidatePath } from "next/cache";
import { after } from "next/server";
import { and, asc, count, desc, eq, gt, lt, or } from "drizzle-orm";
import {
  db,
  isoJobs,
  isoJobTasks,
  type IsoJob,
  type IsoJobTask,
} from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";
import { getSession } from "@/lib/auth-helper";
import { IsoJobUpsertSchema } from "@/lib/schemas/iso-jobs";
import { notifyIsoJobFinished, shouldNotifyIsoJob } from "@/lib/push/iso-job-notifications";
import {
  type PaginationParams,
  type PaginatedResult,
  decodeCursor,
  buildPaginatedResponse,
  DEFAULT_PAGE_SIZE,
} from "@/lib/utils/pagination";

export type IsoJobDetail = IsoJob & { tasks: IsoJobTask[] };

export interface PaginatedIsoJobFilters extends PaginationParams {
  kind?: IsoJob["kind"];
  status?: IsoJob["status"];
}

async function resolveUserId(userId?: string): Promise<string | undefined> {
  if (userId) return userId;
  const session = await getSession();
  return session?.user?.id;
}

/**
 * Lists a user's ISO jobs, newest first. Sorted by start time rather than
 * last update so running jobs do not reshuffle pages while they report.
 */
export async function getIsoJobsPaginated(
  userId?: string,
  filters?: PaginatedIsoJobFilters
): Promise<PaginatedResult<IsoJob>> {
  await ensureSchemaInitialized();

  const resolvedUserId = await resolveUserId(userId);
  if (!resolvedUserId) {
    return {
      data: [],
      pagination: {
        nextCursor: null,
        prevCursor: null,
        hasNextPage: false,
        hasPrevPage: false,
        totalCount: 0,
      },
    };
  }

  const limit = Math.min(Math.max(filters?.limit || DEFAULT_PAGE_SIZE, 1), 100);
  const direction = filters?.direction ?? "next";
  const cursor = filters?.cursor ? decodeCursor(filters.cursor) : null;

  const conditions = [eq(isoJobs.userId, resolvedUserId)];
  if (filters?.kind) conditions.push(eq(isoJobs.kind, filters.kind));
  if (filters?.status) conditions.push(eq(isoJobs.status, filters.status));
  const baseConditions = [...conditions];

  if (cursor) {
    const cursorDate = new Date(cursor.sortValue);
    const cursorCondition =
      direction === "next"
        ? or(
            lt(isoJobs.startedAt, cursorDate),
            and(eq(isoJobs.startedAt, cursorDate), lt(isoJobs.id, cursor.id))
          )
        : or(
            gt(isoJobs.startedAt, cursorDate),
            and(eq(isoJobs.startedAt, cursorDate), gt(isoJobs.id, cursor.id))
          );
    if (cursorCondition) conditions.push(cursorCondition);
  }

  const order =
    direction === "next"
      ? [desc(isoJobs.startedAt), desc(isoJobs.id)]
      : [asc(isoJobs.startedAt), asc(isoJobs.id)];

  const [results, countResult] = await Promise.all([
    db
      .select()
      .from(isoJobs)
      .where(and(...conditions))
      .orderBy(...order)
      .limit(limit + 1),
    db.select({ count: count() }).from(isoJobs).where(and(...baseConditions)),
  ]);

  return buildPaginatedResponse(
    results,
    limit,
    direction,
    (job) => job.startedAt.toISOString(),
    !!cursor,
    countResult[0]?.count ?? 0
  );
}

/** Returns a job with its progress rows, or undefined if it does not exist. */
export async function getIsoJob(id: string): Promise<IsoJobDetail | undefined> {
  await ensureSchemaInitialized();

  const [job] = await db.select().from(isoJobs).where(eq(isoJobs.id, id)).limit(1);
  if (!job) return undefined;

  const tasks = await db
    .select()
    .from(isoJobTasks)
    .where(eq(isoJobTasks.jobId, id))
    .orderBy(asc(isoJobTasks.position));
  return { ...job, tasks };
}

/**
 * Creates or replaces a job from a CLI progress snapshot. The job keeps its
 * creation time; its progress rows are replaced wholesale.
 */
export async function upsertIsoJobAction(
  id: string,
  data: unknown,
  userId?: string
): Promise<{ success: boolean; data?: IsoJobDetail; created?: boolean; error?: string }> {
  try {
    await ensureSchemaInitialized();

    const resolvedUserId = await resolveUserId(userId);
    if (!resolvedUserId) {
      return { success: false, error: "Unauthorized" };
    }
    if (!id || id.length > 128) {
      return { success: false, error: "Invalid job ID" };
    }

    const parsed = IsoJobUpsertSchema.safeParse(data);
    if (!parsed.success) {
      return {
        success: false,
        error: parsed.error.issues
          .map((issue) => `${issue.path.join(".") || "body"}: ${issue.message}`)
          .join("; "),
      };
    }
    const { tasks, ...job } = parsed.data;

    const [existing] = await db
      .select({ userId: isoJobs.userId, status: isoJobs.status })
      .from(isoJobs)
      .where(eq(isoJobs.id, id))
      .limit(1);
    if (existing && existing.userId !== resolvedUserId) {
      return { success: false, error: "Permission denied" };
    }

    const now = new Date();
    const values = {
      ...job,
      hostName: job.hostName ?? null,
      message: job.message ?? null,
      error: job.error ?? null,
      finishedAt: job.finishedAt ?? null,
      updatedAt: now,
    };
    const rows = tasks.map((task, position) => ({
      ...task,
      jobId: id,
      position,
      detail: task.detail ?? null,
      error: task.error ?? null,
    }));

    const writeJob = existing
      ? db.update(isoJobs).set(values).where(eq(isoJobs.id, id))
      : db.insert(isoJobs).values({ ...values, id, userId: resolvedUserId, createdAt: now });
    const clearTasks = db.delete(isoJobTasks).where(eq(isoJobTasks.jobId, id));

    if (rows.length > 0) {
      await db.batch([writeJob, clearTasks, db.insert(isoJobTasks).values(rows)]);
    } else {
      await db.batch([writeJob, clearTasks]);
    }

    if (shouldNotifyIsoJob(existing?.status, job.status)) {
      // Push after the response so the CLI's progress report is not delayed.
      after(() => notifyIsoJobFinished(resolvedUserId, { ...job, id, error: job.error ?? null }));
    }

    revalidatePath("/iso-jobs");
    return { success: true, data: await getIsoJob(id), created: !existing };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to save ISO job",
    };
  }
}

export async function deleteIsoJobAction(
  id: string,
  userId?: string
): Promise<{ success: boolean; error?: string }> {
  try {
    const resolvedUserId = await resolveUserId(userId);
    if (!resolvedUserId) {
      return { success: false, error: "Unauthorized" };
    }

    const [existing] = await db
      .select({ userId: isoJobs.userId })
      .from(isoJobs)
      .where(eq(isoJobs.id, id))
      .limit(1);
    if (!existing) {
      return { success: false, error: "ISO job not found" };
    }
    if (existing.userId !== resolvedUserId) {
      return { success: false, error: "Permission denied" };
    }

    // Delete rows explicitly in case foreign keys are not enforced.
    await db.batch([
      db.delete(isoJobTasks).where(eq(isoJobTasks.jobId, id)),
      db.delete(isoJobs).where(eq(isoJobs.id, id)),
    ]);
    revalidatePath("/iso-jobs");
    return { success: true };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to delete ISO job",
    };
  }
}

export async function deleteIsoJobFormAction(id: string): Promise<void> {
  await deleteIsoJobAction(id);
  revalidatePath("/iso-jobs");
}
