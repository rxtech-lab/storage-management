import { sqliteTable, text, integer, real, index } from "drizzle-orm/sqlite-core";
import { relations } from "drizzle-orm";
import { nanoid } from "nanoid";

/**
 * A long-running ISO job reported by the iso-burner CLI: either generating
 * ISO files from a folder or burning ISO files to discs. The CLI chooses the
 * ID so it can keep updating the same job, including after a resume.
 */
export const isoJobs = sqliteTable(
  "iso_jobs",
  {
    id: text("id").primaryKey(),
    userId: text("user_id").notNull(),
    kind: text("kind", { enum: ["generate", "burn"] }).notNull(),
    title: text("title").notNull(),
    status: text("status", {
      enum: ["running", "completed", "failed", "cancelled", "stopped"],
    }).notNull(),
    hostName: text("host_name"),
    progress: real("progress").notNull().default(0),
    doneCount: integer("done_count").notNull().default(0),
    totalCount: integer("total_count").notNull().default(0),
    doneBytes: integer("done_bytes").notNull().default(0),
    totalBytes: integer("total_bytes").notNull().default(0),
    message: text("message"),
    error: text("error"),
    startedAt: integer("started_at", { mode: "timestamp" }).notNull(),
    finishedAt: integer("finished_at", { mode: "timestamp" }),
    createdAt: integer("created_at", { mode: "timestamp" })
      .notNull()
      .$defaultFn(() => new Date()),
    updatedAt: integer("updated_at", { mode: "timestamp" })
      .notNull()
      .$defaultFn(() => new Date()),
  },
  (table) => [index("iso_jobs_user_updated_idx").on(table.userId, table.updatedAt)]
);

/**
 * One row of a job's progress: an ISO being written, a drive burning discs,
 * or an ISO's burned copies. Rows are replaced on every progress report.
 */
export const isoJobTasks = sqliteTable(
  "iso_job_tasks",
  {
    id: text("id")
      .primaryKey()
      .$defaultFn(() => nanoid()),
    jobId: text("job_id")
      .notNull()
      .references(() => isoJobs.id, { onDelete: "cascade" }),
    section: text("section", { enum: ["iso", "drive"] }).notNull(),
    position: integer("position").notNull(),
    name: text("name").notNull(),
    status: text("status").notNull(),
    detail: text("detail"),
    progress: real("progress").notNull().default(0),
    doneBytes: integer("done_bytes").notNull().default(0),
    totalBytes: integer("total_bytes").notNull().default(0),
    error: text("error"),
  },
  (table) => [index("iso_job_tasks_job_idx").on(table.jobId)]
);

export const isoJobsRelations = relations(isoJobs, ({ many }) => ({
  tasks: many(isoJobTasks),
}));

export const isoJobTasksRelations = relations(isoJobTasks, ({ one }) => ({
  job: one(isoJobs, {
    fields: [isoJobTasks.jobId],
    references: [isoJobs.id],
  }),
}));

export type IsoJob = typeof isoJobs.$inferSelect;
export type NewIsoJob = typeof isoJobs.$inferInsert;
export type IsoJobTask = typeof isoJobTasks.$inferSelect;
export type NewIsoJobTask = typeof isoJobTasks.$inferInsert;
