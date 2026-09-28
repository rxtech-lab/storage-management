import Link from "next/link";
import { formatDistanceToNow } from "date-fns";
import { Disc3, FileArchive } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { PaginationNav } from "@/components/ui/pagination-nav";
import { getIsoJobsPaginated } from "@/lib/actions/iso-job-actions";
import { AutoRefresh } from "@/components/iso-jobs/auto-refresh";
import { ProgressBar } from "@/components/iso-jobs/progress-bar";
import {
  formatBytes,
  isoJobCountLabel,
  isoJobKindLabel,
  isoJobStatusLabels,
  isoJobStatusVariant,
} from "@/components/iso-jobs/iso-job-format";

const PAGE_SIZE = 20;

export default async function IsoJobsPage({
  searchParams,
}: {
  searchParams: Promise<{ cursor?: string; direction?: string }>;
}) {
  const params = await searchParams;
  const direction = (params.direction ?? "next") as "next" | "prev";

  const result = await getIsoJobsPaginated(undefined, {
    cursor: params.cursor,
    direction,
    limit: PAGE_SIZE,
  });
  const jobs = result.data;

  return (
    <div className="flex flex-col gap-6">
      <AutoRefresh enabled={jobs.some((job) => job.status === "running")} />
      <div>
        <h1 className="text-3xl font-bold">ISO Jobs</h1>
        <p className="text-muted-foreground">
          ISO generation and disc burning progress reported by iso-burner
        </p>
      </div>

      {jobs.length === 0 ? (
        <Card>
          <CardContent className="py-12 text-center text-muted-foreground">
            No ISO jobs yet. Sign in from iso-burner to sync its progress here.
          </CardContent>
        </Card>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {jobs.map((job) => {
            const Icon = job.kind === "generate" ? FileArchive : Disc3;
            return (
              <Link key={job.id} href={`/iso-jobs/${job.id}`}>
                <Card className="h-full transition-colors hover:bg-muted/50">
                  <CardHeader className="flex flex-row items-start justify-between gap-2 space-y-0 pb-2">
                    <div className="flex min-w-0 items-center gap-2">
                      <Icon className="size-4 shrink-0 text-muted-foreground" />
                      <CardTitle className="truncate text-lg">{job.title}</CardTitle>
                    </div>
                    <Badge variant={isoJobStatusVariant(job.status)}>
                      {isoJobStatusLabels[job.status]}
                    </Badge>
                  </CardHeader>
                  <CardContent className="flex flex-col gap-2">
                    <p className="text-sm text-muted-foreground">
                      {isoJobKindLabel(job.kind)}
                      {job.hostName ? ` · ${job.hostName}` : ""}
                    </p>
                    <ProgressBar
                      value={job.progress}
                      tone={job.status === "failed" ? "destructive" : job.status === "completed" ? "success" : "default"}
                    />
                    <div className="flex justify-between text-xs text-muted-foreground">
                      <span>{isoJobCountLabel(job)}</span>
                      <span>
                        {Math.round(job.progress * 100)}% · {formatBytes(job.doneBytes)} / {formatBytes(job.totalBytes)}
                      </span>
                    </div>
                    <p className="text-xs text-muted-foreground">
                      Updated {formatDistanceToNow(new Date(job.updatedAt), { addSuffix: true })}
                    </p>
                  </CardContent>
                </Card>
              </Link>
            );
          })}
        </div>
      )}

      <PaginationNav
        nextCursor={result.pagination.nextCursor}
        prevCursor={result.pagination.prevCursor}
        hasNextPage={result.pagination.hasNextPage}
        hasPrevPage={result.pagination.hasPrevPage}
      />
    </div>
  );
}
