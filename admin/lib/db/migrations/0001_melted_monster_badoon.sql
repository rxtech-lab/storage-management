CREATE TABLE `upload_files` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`user_id` text NOT NULL,
	`key` text NOT NULL,
	`filename` text NOT NULL,
	`content_type` text NOT NULL,
	`size` integer NOT NULL,
	`item_id` integer,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`item_id`) REFERENCES `items`(`id`) ON UPDATE no action ON DELETE set null
);
--> statement-breakpoint
ALTER TABLE `authors` ADD `user_id` text NOT NULL;--> statement-breakpoint
ALTER TABLE `categories` ADD `user_id` text NOT NULL;--> statement-breakpoint
ALTER TABLE `items` ADD `user_id` text NOT NULL;--> statement-breakpoint
ALTER TABLE `locations` ADD `user_id` text NOT NULL;--> statement-breakpoint
ALTER TABLE `position_schemas` ADD `user_id` text NOT NULL;--> statement-breakpoint
ALTER TABLE `positions` ADD `user_id` text NOT NULL;