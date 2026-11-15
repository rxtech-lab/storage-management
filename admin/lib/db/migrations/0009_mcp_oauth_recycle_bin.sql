CREATE TABLE `device_tokens` (
	`token` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`platform` text NOT NULL,
	`environment` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
);
--> statement-breakpoint
CREATE INDEX `device_tokens_user_idx` ON `device_tokens` (`user_id`);--> statement-breakpoint
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
CREATE INDEX `iso_job_tasks_job_idx` ON `iso_job_tasks` (`job_id`);--> statement-breakpoint
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
CREATE INDEX `iso_jobs_user_updated_idx` ON `iso_jobs` (`user_id`,`updated_at`);--> statement-breakpoint
CREATE TABLE `item_stocks` (
	`id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`item_id` text NOT NULL,
	`parent_id` text,
	`location_id` text,
	`images` text DEFAULT '[]',
	`note` text,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	FOREIGN KEY (`item_id`) REFERENCES `items`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`location_id`) REFERENCES `locations`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE INDEX `item_stocks_item_idx` ON `item_stocks` (`item_id`);--> statement-breakpoint
CREATE INDEX `item_stocks_parent_idx` ON `item_stocks` (`parent_id`);--> statement-breakpoint
CREATE TABLE `item_tags` (
	`id` text PRIMARY KEY NOT NULL,
	`item_id` text NOT NULL,
	`tag_id` text NOT NULL,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`item_id`) REFERENCES `items`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`tag_id`) REFERENCES `tags`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE UNIQUE INDEX `item_tags_item_id_tag_id_unique` ON `item_tags` (`item_id`,`tag_id`);--> statement-breakpoint
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
CREATE INDEX `live_activity_tokens_user_idx` ON `live_activity_tokens` (`user_id`);--> statement-breakpoint
CREATE TABLE `tags` (
	`id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`title` text NOT NULL,
	`color` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
);
--> statement-breakpoint
CREATE TABLE `mcp_oauth_clients` (
	`id` text PRIMARY KEY NOT NULL,
	`name` text NOT NULL,
	`redirect_uris` text NOT NULL,
	`created_at` integer DEFAULT (cast(unixepoch('subsecond') * 1000 as integer)) NOT NULL
);
--> statement-breakpoint
CREATE INDEX `mcp_oauth_clients_created_idx` ON `mcp_oauth_clients` (`created_at`);--> statement-breakpoint
CREATE TABLE `mcp_oauth_codes` (
	`hash` text PRIMARY KEY NOT NULL,
	`grant_id` text NOT NULL,
	`redirect_uri` text NOT NULL,
	`challenge` text NOT NULL,
	`used_at` integer,
	`expires_at` integer NOT NULL,
	FOREIGN KEY (`grant_id`) REFERENCES `mcp_oauth_grants`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `mcp_oauth_codes_expiry_idx` ON `mcp_oauth_codes` (`expires_at`);--> statement-breakpoint
CREATE TABLE `mcp_oauth_grants` (
	`id` text PRIMARY KEY NOT NULL,
	`owner_id` text NOT NULL,
	`client_id` text NOT NULL,
	`resource` text NOT NULL,
	`scope` text NOT NULL,
	`revoked_at` integer,
	`expires_at` integer NOT NULL,
	FOREIGN KEY (`client_id`) REFERENCES `mcp_oauth_clients`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `mcp_oauth_grants_owner_idx` ON `mcp_oauth_grants` (`owner_id`);--> statement-breakpoint
CREATE INDEX `mcp_oauth_grants_expiry_idx` ON `mcp_oauth_grants` (`expires_at`);--> statement-breakpoint
CREATE TABLE `mcp_oauth_requests` (
	`id` text PRIMARY KEY NOT NULL,
	`state_hash` text NOT NULL,
	`client_id` text NOT NULL,
	`redirect_uri` text NOT NULL,
	`client_state` text,
	`challenge` text NOT NULL,
	`scope` text NOT NULL,
	`upstream_verifier` text NOT NULL,
	`login_claimed_at` integer,
	`owner_id` text,
	`consent_hash` text,
	`expires_at` integer NOT NULL,
	FOREIGN KEY (`client_id`) REFERENCES `mcp_oauth_clients`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE UNIQUE INDEX `mcp_oauth_requests_state_hash_unique` ON `mcp_oauth_requests` (`state_hash`);--> statement-breakpoint
CREATE INDEX `mcp_oauth_requests_expiry_idx` ON `mcp_oauth_requests` (`expires_at`);--> statement-breakpoint
CREATE TABLE `mcp_oauth_tokens` (
	`hash` text PRIMARY KEY NOT NULL,
	`grant_id` text NOT NULL,
	`kind` text NOT NULL,
	`used_at` integer,
	`expires_at` integer NOT NULL,
	FOREIGN KEY (`grant_id`) REFERENCES `mcp_oauth_grants`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `mcp_oauth_tokens_grant_idx` ON `mcp_oauth_tokens` (`grant_id`);--> statement-breakpoint
CREATE INDEX `mcp_oauth_tokens_expiry_idx` ON `mcp_oauth_tokens` (`expires_at`);--> statement-breakpoint
ALTER TABLE `items` ADD `deleted_at` integer;--> statement-breakpoint
