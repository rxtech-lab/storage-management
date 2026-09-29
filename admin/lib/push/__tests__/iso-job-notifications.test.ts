import { describe, it, expect, vi } from "vitest";

vi.mock("@/lib/db", () => ({ db: {}, deviceTokens: {} }));

import { shouldNotifyIsoJob } from "../iso-job-notifications";
import { isInvalidTokenResult } from "../apns";

describe("shouldNotifyIsoJob", () => {
  it("notifies when a running job completes or fails", () => {
    expect(shouldNotifyIsoJob("running", "completed")).toBe(true);
    expect(shouldNotifyIsoJob("running", "failed")).toBe(true);
  });

  it("notifies when a job is first reported already finished", () => {
    expect(shouldNotifyIsoJob(undefined, "completed")).toBe(true);
  });

  it("does not notify for repeated reports of the same status", () => {
    expect(shouldNotifyIsoJob("completed", "completed")).toBe(false);
    expect(shouldNotifyIsoJob("failed", "failed")).toBe(false);
  });

  it("does not notify for running, cancelled or stopped jobs", () => {
    expect(shouldNotifyIsoJob(undefined, "running")).toBe(false);
    expect(shouldNotifyIsoJob("running", "cancelled")).toBe(false);
    expect(shouldNotifyIsoJob("running", "stopped")).toBe(false);
  });
});

describe("isInvalidTokenResult", () => {
  it("treats unregistered and bad tokens as invalid", () => {
    expect(isInvalidTokenResult({ token: "a", status: 410, reason: "Unregistered" })).toBe(true);
    expect(isInvalidTokenResult({ token: "a", status: 400, reason: "BadDeviceToken" })).toBe(true);
  });

  it("keeps tokens on transient failures", () => {
    expect(isInvalidTokenResult({ token: "a", status: 200 })).toBe(false);
    expect(isInvalidTokenResult({ token: "a", status: 429, reason: "TooManyRequests" })).toBe(false);
    expect(isInvalidTokenResult({ token: "a", status: 0, reason: "ECONNRESET" })).toBe(false);
  });
});
