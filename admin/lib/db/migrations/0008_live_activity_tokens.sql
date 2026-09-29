CREATE TABLE `live_activity_tokens` (
	`token` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`kind` text NOT NULL,
	`environment` text NOT NULL,
	`last_pushed_at` integer,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
);
--> statement-breakpoint
CREATE INDEX `live_activity_tokens_user_idx` ON `live_activity_tokens` (`user_id`);
