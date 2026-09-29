import { and, asc, count, eq, inArray, isNull, lt, or } from "drizzle-orm";
import { db, isoJobs, liveActivityTokens, type IsoJob } from "@/lib/db";
import {
  isApnsConfigured,
  isInvalidTokenResult,
  logApnsResults,
  sendApnsLiveActivity,
  type ApnsEnvironment,
  type ApnsResult,
} from "./apns";
import { KIND_LABELS } from "./iso-job-notifications";

/** Must match the Swift `IsoJobActivityAttributes` type name. */
const ATTRIBUTES_TYPE = "IsoJobActivityAttributes";

/** Running jobs listed in the activity; the rest are summarized as a count. */
export const MAX_ACTIVITY_JOBS = 3;

// Progress reports arrive every second or so; APNs budgets Live Activity
// updates, so plain progress pushes go out at most this often.
export const UPDATE_INTERVAL_MS = 10_000;

// A start push is not repeated within this window, so jobs starting together
// share one activity while the app registers the new activity's update token.
const START_COOLDOWN_MS = 60_000;

// ActivityKit ends an activity after 8 hours, so older update tokens are dead.
const STALE_TOKEN_MS = 8 * 60 * 60 * 1000;

// How long the activity stays on the Lock Screen after the last job ends
const DISMISS_AFTER_MS = 15 * 60 * 1000;

// Keeps the content state well under APNs' 4 KB payload limit
const MAX_TITLE_LENGTH = 80;
const MAX_DETAIL_LENGTH = 120;

export type LiveActivityEvent = "start" | "update" | "end";

export type LiveActivityJob = Pick<
  IsoJob,
  | "id"
  | "kind"
  | "title"
  | "status"
  | "hostName"
  | "progress"
  | "doneCount"
  | "totalCount"
  | "doneBytes"
  | "totalBytes"
  | "message"
  | "error"
>;

/**
 * How a job's status change from `previous` to `next` affects the activity:
 * a job that starts running may start it, further running reports update it,
 * and leaving the running state updates it or, for the last job, ends it.
 */
export function liveActivityEventFor(
  previous: IsoJob["status"] | undefined,
  next: IsoJob["status"]
): LiveActivityEvent | null {
  if (next === "running") {
    return previous === "running" ? "update" : "start";
  }
  return previous === "running" ? "end" : null;
}

function truncate(value: string | null | undefined, maxLength: number): string | null {
  if (!value) return null;
  return value.length > maxLength ? `${value.slice(0, maxLength - 1)}…` : value;
}

/** One job row; keys must match the Swift `IsoJobActivityAttributes.Job`. */
export function buildJobSnapshot(job: LiveActivityJob) {
  return {
    id: job.id,
    kind: job.kind,
    title: truncate(job.title, MAX_TITLE_LENGTH) ?? "",
    hostName: truncate(job.hostName, MAX_TITLE_LENGTH),
    status: job.status,
    progress: job.progress,
    doneCount: job.doneCount,
    totalCount: job.totalCount,
    doneBytes: job.doneBytes,
    totalBytes: job.totalBytes,
    message: truncate(job.message, MAX_DETAIL_LENGTH),
    error: truncate(job.error, MAX_DETAIL_LENGTH),
  };
}

/** The activity's dynamic state; keys must match the Swift `ContentState`. */
export function buildContentState(jobs: LiveActivityJob[], runningCount: number) {
  return {
    jobs: jobs.slice(0, MAX_ACTIVITY_JOBS).map(buildJobSnapshot),
    runningCount,
  };
}

type ContentState = ReturnType<typeof buildContentState>;

export function buildLiveActivityAps(
  event: LiveActivityEvent,
  state: ContentState,
  now: Date,
  startedJob?: LiveActivityJob
): Record<string, unknown> {
  const base = {
    timestamp: Math.floor(now.getTime() / 1000),
    event,
    "content-state": state,
  };

  switch (event) {
    case "start":
      return {
        ...base,
        "attributes-type": ATTRIBUTES_TYPE,
        attributes: {},
        alert: startedJob
          ? { title: `${KIND_LABELS[startedJob.kind]} started`, body: startedJob.title }
          : { title: "ISO jobs started", body: `${state.runningCount} jobs running` },
        // Ask ActivityKit to create an update token and hand it to the app
        "input-push-token": 1,
      };
    case "update":
      return base;
    case "end":
      return {
        ...base,
        "dismissal-date": Math.floor((now.getTime() + DISMISS_AFTER_MS) / 1000),
      };
  }
}

type TokenRow = { token: string; environment: ApnsEnvironment; lastPushedAt: Date | null };

async function push(
  userId: string,
  tokens: TokenRow[],
  aps: Record<string, unknown>,
  now: Date
): Promise<void> {
  await db
    .update(liveActivityTokens)
    .set({ lastPushedAt: now })
    .where(inArray(liveActivityTokens.token, tokens.map((row) => row.token)));

  const byEnvironment = new Map<ApnsEnvironment, string[]>();
  for (const row of tokens) {
    byEnvironment.set(row.environment, [...(byEnvironment.get(row.environment) ?? []), row.token]);
  }
  const results: ApnsResult[] = (
    await Promise.all(
      [...byEnvironment].map(async ([environment, list]) => {
        const envResults = await sendApnsLiveActivity(environment, list, aps, 10);
        logApnsResults(`liveactivity event=${String(aps.event)} user=${userId}`, environment, envResults);
        return envResults;
      })
    )
  ).flat();

  const invalidTokens = results.filter(isInvalidTokenResult).map((result) => result.token);
  if (invalidTokens.length > 0) {
    await db
      .delete(liveActivityTokens)
      .where(and(eq(liveActivityTokens.userId, userId), inArray(liveActivityTokens.token, invalidTokens)));
  }
}

/**
 * Brings the user's ISO jobs Live Activity in line with their running jobs
 * after `job` reported `event`. The activity lists up to three running jobs;
 * it is started over push-to-start when a job starts and no activity exists,
 * and ended when the last running job ends.
 */
export async function syncIsoJobLiveActivity(
  userId: string,
  event: LiveActivityEvent,
  job: LiveActivityJob
): Promise<void> {
  if (!isApnsConfigured()) return;

  try {
    const now = new Date();
    const tokenColumns = {
      token: liveActivityTokens.token,
      environment: liveActivityTokens.environment,
      lastPushedAt: liveActivityTokens.lastPushedAt,
    };

    await db
      .delete(liveActivityTokens)
      .where(
        and(
          eq(liveActivityTokens.userId, userId),
          eq(liveActivityTokens.kind, "update"),
          lt(liveActivityTokens.updatedAt, new Date(now.getTime() - STALE_TOKEN_MS))
        )
      );

    const runningFilter = and(eq(isoJobs.userId, userId), eq(isoJobs.status, "running"));
    const [[{ runningCount }], running, updateTokens] = await Promise.all([
      db.select({ runningCount: count() }).from(isoJobs).where(runningFilter),
      db
        .select()
        .from(isoJobs)
        .where(runningFilter)
        .orderBy(asc(isoJobs.startedAt))
        .limit(MAX_ACTIVITY_JOBS),
      db
        .select(tokenColumns)
        .from(liveActivityTokens)
        .where(and(eq(liveActivityTokens.userId, userId), eq(liveActivityTokens.kind, "update"))),
    ]);

    if (runningCount === 0) {
      // The last job ended: show its outcome, then let the activity go
      if (event !== "end" || updateTokens.length === 0) return;
      await push(userId, updateTokens, buildLiveActivityAps("end", buildContentState([job], 0), now), now);
      await db
        .delete(liveActivityTokens)
        .where(and(eq(liveActivityTokens.userId, userId), eq(liveActivityTokens.kind, "update")));
      return;
    }

    const state = buildContentState(running, runningCount);

    if (updateTokens.length === 0) {
      // No activity yet; only a newly started job starts one
      if (event !== "start") return;
      const startTokens = await db
        .select(tokenColumns)
        .from(liveActivityTokens)
        .where(
          and(
            eq(liveActivityTokens.userId, userId),
            eq(liveActivityTokens.kind, "start"),
            or(
              isNull(liveActivityTokens.lastPushedAt),
              lt(liveActivityTokens.lastPushedAt, new Date(now.getTime() - START_COOLDOWN_MS))
            )
          )
        );
      if (startTokens.length === 0) return;
      await push(userId, startTokens, buildLiveActivityAps("start", state, now, job), now);
      return;
    }

    // Jobs starting or ending change the list right away; progress is throttled
    const targets =
      event === "update"
        ? updateTokens.filter(
            (row) => !row.lastPushedAt || now.getTime() - row.lastPushedAt.getTime() >= UPDATE_INTERVAL_MS
          )
        : updateTokens;
    if (targets.length === 0) return;
    await push(userId, targets, buildLiveActivityAps("update", state, now), now);
  } catch (error) {
    console.error(`Failed to sync ISO jobs Live Activity after job ${job.id} ${event}:`, error);
  }
}
