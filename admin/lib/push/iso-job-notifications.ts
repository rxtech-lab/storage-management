import { and, eq, inArray } from "drizzle-orm";
import { db, deviceTokens, type IsoJob } from "@/lib/db";
import {
  isApnsConfigured,
  isInvalidTokenResult,
  logApnsResults,
  sendApnsAlert,
  type ApnsAlert,
  type ApnsEnvironment,
} from "./apns";

// Cancelled and stopped jobs were ended by the user on the CLI host, so only
// outcomes they did not trigger themselves are pushed.
const NOTIFIED_STATUSES: IsoJob["status"][] = ["completed", "failed"];

export const KIND_LABELS: Record<IsoJob["kind"], string> = {
  generate: "ISO generation",
  burn: "Disc burning",
  upload: "Upload",
};

/** Whether a status change from `previous` to `next` should notify the user. */
export function shouldNotifyIsoJob(
  previous: IsoJob["status"] | undefined,
  next: IsoJob["status"]
): boolean {
  return previous !== next && NOTIFIED_STATUSES.includes(next);
}

function buildAlert(job: Pick<IsoJob, "id" | "kind" | "title" | "status" | "doneCount" | "totalCount" | "error">): ApnsAlert {
  const label = KIND_LABELS[job.kind];
  const counts = job.totalCount > 0 ? ` (${job.doneCount}/${job.totalCount})` : "";

  return job.status === "completed"
    ? {
        title: `${label} finished`,
        body: `${job.title}${counts}`,
        threadId: "iso-jobs",
        data: { isoJobId: job.id },
      }
    : {
        title: `${label} failed`,
        body: job.error ? `${job.title}: ${job.error}` : job.title,
        threadId: "iso-jobs",
        data: { isoJobId: job.id },
      };
}

/**
 * Pushes a job's final status to every device the user registered, and
 * removes tokens APNs reports as no longer valid.
 */
export async function notifyIsoJobFinished(
  userId: string,
  job: Pick<IsoJob, "id" | "kind" | "title" | "status" | "doneCount" | "totalCount" | "error">
): Promise<void> {
  if (!isApnsConfigured()) return;

  try {
    const devices = await db
      .select({ token: deviceTokens.token, environment: deviceTokens.environment })
      .from(deviceTokens)
      .where(eq(deviceTokens.userId, userId));
    if (devices.length === 0) return;

    const alert = buildAlert(job);
    const byEnvironment = new Map<ApnsEnvironment, string[]>();
    for (const device of devices) {
      byEnvironment.set(device.environment, [
        ...(byEnvironment.get(device.environment) ?? []),
        device.token,
      ]);
    }

    const results = (
      await Promise.all(
        [...byEnvironment].map(async ([environment, tokens]) => {
          const envResults = await sendApnsAlert(environment, tokens, alert);
          logApnsResults(`alert job=${job.id} status=${job.status}`, environment, envResults);
          return envResults;
        })
      )
    ).flat();

    const invalidTokens = results.filter(isInvalidTokenResult).map((result) => result.token);
    if (invalidTokens.length > 0) {
      await db
        .delete(deviceTokens)
        .where(and(eq(deviceTokens.userId, userId), inArray(deviceTokens.token, invalidTokens)));
    }
  } catch (error) {
    console.error(`Failed to send ISO job ${job.id} notification:`, error);
  }
}
