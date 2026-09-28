import type { IsoJob } from "@/lib/db";

export const isoJobStatusLabels: Record<IsoJob["status"], string> = {
  running: "Running",
  completed: "Completed",
  failed: "Failed",
  cancelled: "Cancelled",
  stopped: "Stopped",
};

export function isoJobStatusVariant(
  status: IsoJob["status"]
): "default" | "secondary" | "destructive" | "outline" {
  switch (status) {
    case "running":
      return "default";
    case "completed":
      return "secondary";
    case "failed":
      return "destructive";
    default:
      return "outline";
  }
}

export function isoJobKindLabel(kind: IsoJob["kind"]): string {
  return kind === "generate" ? "Generate ISO" : "Burn discs";
}

export function isoJobCountLabel(job: Pick<IsoJob, "kind" | "doneCount" | "totalCount">): string {
  const noun = job.kind === "generate" ? "ISO file(s)" : "disc(s)";
  return `${job.doneCount} of ${job.totalCount} ${noun}`;
}

/** Formats bytes with binary units, matching the iso-burner CLI. */
export function formatBytes(bytes: number): string {
  const units = ["B", "KiB", "MiB", "GiB", "TiB"];
  let value = bytes;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return unit === 0 ? `${bytes} B` : `${value.toFixed(1)} ${units[unit]}`;
}
