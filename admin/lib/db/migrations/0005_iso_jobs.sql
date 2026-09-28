CREATE TABLE `iso_jobs` (
	`id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`kind` text NOT NULL,
	`title` text NOT NULL,
	`status` text NOT NULL,
	`host_name` text,
	`progress` real DEFAULT 0 NOT NULL,
	`done_count` integer DEFAULT 0 NOT NULL,
	`total_count` integer DEFAULT 0 NOT NULL,
	`done_bytes` integer DEFAULT 0 NOT NULL,
	`total_bytes` integer DEFAULT 0 NOT NULL,
	`message` text,
	`error` text,
	`started_at` integer NOT NULL,
	`finished_at` integer,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
);
--> statement-breakpoint
CREATE INDEX `iso_jobs_user_updated_idx` ON `iso_jobs` (`user_id`,`updated_at`);
--> statement-breakpoint
CREATE TABLE `iso_job_tasks` (
	`id` text PRIMARY KEY NOT NULL,
	`job_id` text NOT NULL,
	`section` text NOT NULL,
	`position` integer NOT NULL,
	`name` text NOT NULL,
	`status` text NOT NULL,
	`detail` text,
	`progress` real DEFAULT 0 NOT NULL,
	`done_bytes` integer DEFAULT 0 NOT NULL,
	`total_bytes` integer DEFAULT 0 NOT NULL,
	`error` text,
	FOREIGN KEY (`job_id`) REFERENCES `iso_jobs`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `iso_job_tasks_job_idx` ON `iso_job_tasks` (`job_id`);
