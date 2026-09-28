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

const isoJobKindLabels: Record<IsoJob["kind"], string> = {
  generate: "Generate ISO",
  burn: "Burn discs",
  upload: "Upload content",
};

const isoJobCountNouns: Record<IsoJob["kind"], string> = {
  generate: "ISO file(s)",
  burn: "disc(s)",
  upload: "file(s)",
};

export function isoJobKindLabel(kind: IsoJob["kind"]): string {
  return isoJobKindLabels[kind];
}

export function isoJobCountLabel(job: Pick<IsoJob, "kind" | "doneCount" | "totalCount">): string {
  return `${job.doneCount} of ${job.totalCount} ${isoJobCountNouns[job.kind]}`;
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
