import { notFound } from "next/navigation";
import { format, formatDistanceToNow } from "date-fns";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { getSession } from "@/lib/auth-helper";
import { getIsoJob } from "@/lib/actions/iso-job-actions";
import type { IsoJobTask } from "@/lib/db";
import { AutoRefresh } from "@/components/iso-jobs/auto-refresh";
import { DeleteIsoJobButton } from "@/components/iso-jobs/delete-iso-job-button";
import { ProgressBar } from "@/components/iso-jobs/progress-bar";
import {
  formatBytes,
  isoJobCountLabel,
  isoJobKindLabel,
  isoJobStatusLabels,
  isoJobStatusVariant,
} from "@/components/iso-jobs/iso-job-format";

export default async function IsoJobPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const [session, job] = await Promise.all([getSession(), getIsoJob(id)]);
  if (!job || job.userId !== session?.user?.id) {
    notFound();
  }

  const drives = job.tasks.filter((task) => task.section === "drive");
  const isos = job.tasks.filter((task) => task.section === "iso");
  const files = job.tasks.filter((task) => task.section === "file");

  return (
    <div className="flex flex-col gap-6">
      <AutoRefresh enabled={job.status === "running"} />
      <div className="flex items-start justify-between gap-4">
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            <h1 className="truncate text-3xl font-bold">{job.title}</h1>
            <Badge variant={isoJobStatusVariant(job.status)}>{isoJobStatusLabels[job.status]}</Badge>
          </div>
          <p className="text-muted-foreground">
            {isoJobKindLabel(job.kind)}
            {job.hostName ? ` on ${job.hostName}` : ""} · started{" "}
            {format(new Date(job.startedAt), "yyyy-MM-dd HH:mm")}
          </p>
        </div>
        <DeleteIsoJobButton id={job.id} title={job.title} />
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Overall progress</CardTitle>
        </CardHeader>
        <CardContent className="flex flex-col gap-2">
          <ProgressBar
            value={job.progress}
            className="h-3"
            tone={job.status === "failed" ? "destructive" : job.status === "completed" ? "success" : "default"}
          />
          <div className="flex flex-wrap justify-between gap-2 text-sm text-muted-foreground">
            <span>{isoJobCountLabel(job)}</span>
            <span>
              {Math.round(job.progress * 100)}% · {formatBytes(job.doneBytes)} / {formatBytes(job.totalBytes)}
            </span>
          </div>
          {job.message && <p className="text-sm">{job.message}</p>}
          {job.error && <p className="text-sm text-destructive">{job.error}</p>}
          <p className="text-xs text-muted-foreground">
            Last report {formatDistanceToNow(new Date(job.updatedAt), { addSuffix: true })}
            {job.finishedAt ? ` · finished ${format(new Date(job.finishedAt), "yyyy-MM-dd HH:mm")}` : ""}
          </p>
        </CardContent>
      </Card>

      {drives.length > 0 && <TaskSection title="Drives" tasks={drives} />}
      {isos.length > 0 && <TaskSection title="ISO files" tasks={isos} />}
      {files.length > 0 && <TaskSection title="Files" tasks={files} />}
    </div>
  );
}

function TaskSection({ title, tasks }: { title: string; tasks: IsoJobTask[] }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>{title}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col divide-y">
        {tasks.map((task) => (
          <div key={task.id} className="flex flex-col gap-1.5 py-3 first:pt-0 last:pb-0">
            <div className="flex items-center justify-between gap-2">
              <span className="truncate font-medium">{task.name}</span>
              <span className="shrink-0 text-sm text-muted-foreground">
                {task.status} · {Math.round(task.progress * 100)}%
              </span>
            </div>
            <ProgressBar
              value={task.progress}
              tone={task.error && task.status === "failed" ? "destructive" : task.progress >= 1 ? "success" : "default"}
            />
            {(task.detail || task.totalBytes > 0) && (
              <p className="text-xs text-muted-foreground">
                {task.detail}
                {task.detail && task.totalBytes > 0 ? " · " : ""}
                {task.totalBytes > 0 ? `${formatBytes(task.doneBytes)} / ${formatBytes(task.totalBytes)}` : ""}
              </p>
            )}
            {task.error && <p className="text-xs text-destructive">{task.error}</p>}
          </div>
        ))}
      </CardContent>
    </Card>
  );
}
