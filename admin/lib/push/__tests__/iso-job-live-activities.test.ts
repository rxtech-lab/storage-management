import { describe, it, expect, vi } from "vitest";

vi.mock("@/lib/db", () => ({ db: {}, deviceTokens: {}, isoJobs: {}, liveActivityTokens: {} }));

import {
  buildContentState,
  buildLiveActivityAps,
  liveActivityEventFor,
  type LiveActivityJob,
} from "../iso-job-live-activities";

const job: LiveActivityJob = {
  id: "job-1",
  kind: "burn",
  title: "Photos 2024",
  status: "running",
  hostName: "studio-mac",
  progress: 0.5,
  doneCount: 1,
  totalCount: 2,
  doneBytes: 100,
  totalBytes: 200,
  message: "Burning disc 2",
  error: null,
};
const now = new Date("2026-09-29T12:00:00Z");

describe("liveActivityEventFor", () => {
  it("starts an activity when a job starts running", () => {
    expect(liveActivityEventFor(undefined, "running")).toBe("start");
    expect(liveActivityEventFor("stopped", "running")).toBe("start");
  });

  it("updates while the job keeps running", () => {
    expect(liveActivityEventFor("running", "running")).toBe("update");
  });

  it("ends the activity when the job leaves the running state", () => {
    expect(liveActivityEventFor("running", "completed")).toBe("end");
    expect(liveActivityEventFor("running", "failed")).toBe("end");
    expect(liveActivityEventFor("running", "cancelled")).toBe("end");
    expect(liveActivityEventFor("running", "stopped")).toBe("end");
  });

  it("does nothing for jobs that were never running", () => {
    expect(liveActivityEventFor(undefined, "completed")).toBeNull();
    expect(liveActivityEventFor("completed", "completed")).toBeNull();
  });
});

describe("buildContentState", () => {
  it("lists at most three jobs and keeps the running count", () => {
    const jobs = [1, 2, 3, 4, 5].map((n) => ({ ...job, id: `job-${n}` }));
    const state = buildContentState(jobs, 5);
    expect(state.jobs.map((row) => row.id)).toEqual(["job-1", "job-2", "job-3"]);
    expect(state.runningCount).toBe(5);
  });

  it("truncates long text to keep the payload small", () => {
    const state = buildContentState([{ ...job, title: "x".repeat(500), error: "e".repeat(2000) }], 1);
    expect(state.jobs[0].title).toHaveLength(80);
    expect(state.jobs[0].error).toHaveLength(120);
  });
});

describe("buildLiveActivityAps", () => {
  it("includes attributes and an alert for the started job", () => {
    const aps = buildLiveActivityAps("start", buildContentState([job], 1), now, job);
    expect(aps).toMatchObject({
      event: "start",
      timestamp: now.getTime() / 1000,
      "attributes-type": "IsoJobActivityAttributes",
      attributes: {},
      alert: { title: "Disc burning started", body: "Photos 2024" },
      "content-state": {
        runningCount: 1,
        jobs: [{ id: "job-1", kind: "burn", status: "running", progress: 0.5, hostName: "studio-mac" }],
      },
    });
  });

  it("only sends the content state when updating", () => {
    const aps = buildLiveActivityAps("update", buildContentState([job], 1), now);
    expect(Object.keys(aps).sort()).toEqual(["content-state", "event", "timestamp"]);
  });

  it("sets a dismissal date when ending", () => {
    const aps = buildLiveActivityAps("end", buildContentState([{ ...job, status: "completed" }], 0), now);
    expect(aps["dismissal-date"]).toBe(now.getTime() / 1000 + 15 * 60);
    expect(aps["content-state"]).toMatchObject({ runningCount: 0, jobs: [{ status: "completed" }] });
  });
});
