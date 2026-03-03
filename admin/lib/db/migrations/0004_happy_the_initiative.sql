CREATE TABLE `account_deletions` (
	`id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`user_email` text,
	`scheduled_at` integer NOT NULL,
	`qstash_message_id` text,
	`status` text DEFAULT 'pending' NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
);
--> statement-breakpoint
CREATE TABLE `stock_histories` (
	`id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`item_id` text NOT NULL,
	`quantity` integer NOT NULL,
	`note` text,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`item_id`) REFERENCES `items`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
PRAGMA foreign_keys=OFF;--> statement-breakpoint
CREATE TABLE `__new_authors` (
	`id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`name` text NOT NULL,
	`bio` text,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
);
--> statement-breakpoint
INSERT INTO `__new_authors`("id", "user_id", "name", "bio", "created_at", "updated_at") SELECT "id", "user_id", "name", "bio", "created_at", "updated_at" FROM `authors`;--> statement-breakpoint
DROP TABLE `authors`;--> statement-breakpoint
ALTER TABLE `__new_authors` RENAME TO `authors`;--> statement-breakpoint
PRAGMA foreign_keys=ON;--> statement-breakpoint
CREATE TABLE `__new_categories` (
	`id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`name` text NOT NULL,
	`description` text,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
);
--> statement-breakpoint
INSERT INTO `__new_categories`("id", "user_id", "name", "description", "created_at", "updated_at") SELECT "id", "user_id", "name", "description", "created_at", "updated_at" FROM `categories`;--> statement-breakpoint
DROP TABLE `categories`;--> statement-breakpoint
ALTER TABLE `__new_categories` RENAME TO `categories`;--> statement-breakpoint
CREATE TABLE `__new_contents` (
	`id` text PRIMARY KEY NOT NULL,
	`item_id` text NOT NULL,
	`type` text NOT NULL,
	`data` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	FOREIGN KEY (`item_id`) REFERENCES `items`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
INSERT INTO `__new_contents`("id", "item_id", "type", "data", "created_at", "updated_at") SELECT "id", "item_id", "type", "data", "created_at", "updated_at" FROM `contents`;--> statement-breakpoint
DROP TABLE `contents`;--> statement-breakpoint
ALTER TABLE `__new_contents` RENAME TO `contents`;--> statement-breakpoint
CREATE TABLE `__new_item_whitelists` (
	`id` text PRIMARY KEY NOT NULL,
	`item_id` text NOT NULL,
	`email` text NOT NULL,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`item_id`) REFERENCES `items`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
INSERT INTO `__new_item_whitelists`("id", "item_id", "email", "created_at") SELECT "id", "item_id", "email", "created_at" FROM `item_whitelists`;--> statement-breakpoint
DROP TABLE `item_whitelists`;--> statement-breakpoint
ALTER TABLE `__new_item_whitelists` RENAME TO `item_whitelists`;--> statement-breakpoint
CREATE TABLE `__new_items` (
	`id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`title` text NOT NULL,
	`description` text,
	`original_qr_code` text,
	`category_id` text,
	`location_id` text,
	`author_id` text,
	`parent_id` text,
	`price` real,
	`currency` text DEFAULT 'USD',
	`visibility` text DEFAULT 'privateAccess' NOT NULL,
	`images` text DEFAULT '[]',
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	FOREIGN KEY (`category_id`) REFERENCES `categories`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`location_id`) REFERENCES `locations`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`author_id`) REFERENCES `authors`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
INSERT INTO `__new_items`("id", "user_id", "title", "description", "original_qr_code", "category_id", "location_id", "author_id", "parent_id", "price", "currency", "visibility", "images", "created_at", "updated_at") SELECT "id", "user_id", "title", "description", "original_qr_code", "category_id", "location_id", "author_id", "parent_id", "price", "currency", "visibility", "images", "created_at", "updated_at" FROM `items`;--> statement-breakpoint
DROP TABLE `items`;--> statement-breakpoint
ALTER TABLE `__new_items` RENAME TO `items`;--> statement-breakpoint
CREATE TABLE `__new_locations` (
	`id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`title` text NOT NULL,
	`latitude` real NOT NULL,
	`longitude` real NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
);
--> statement-breakpoint
INSERT INTO `__new_locations`("id", "user_id", "title", "latitude", "longitude", "created_at", "updated_at") SELECT "id", "user_id", "title", "latitude", "longitude", "created_at", "updated_at" FROM `locations`;--> statement-breakpoint
DROP TABLE `locations`;--> statement-breakpoint
ALTER TABLE `__new_locations` RENAME TO `locations`;--> statement-breakpoint
CREATE TABLE `__new_position_schemas` (
	`id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`name` text NOT NULL,
	`schema` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
);
--> statement-breakpoint
INSERT INTO `__new_position_schemas`("id", "user_id", "name", "schema", "created_at", "updated_at") SELECT "id", "user_id", "name", "schema", "created_at", "updated_at" FROM `position_schemas`;--> statement-breakpoint
DROP TABLE `position_schemas`;--> statement-breakpoint
ALTER TABLE `__new_position_schemas` RENAME TO `position_schemas`;--> statement-breakpoint
CREATE TABLE `__new_positions` (
	`id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`item_id` text NOT NULL,
	`position_schema_id` text NOT NULL,
	`data` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	FOREIGN KEY (`item_id`) REFERENCES `items`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`position_schema_id`) REFERENCES `position_schemas`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
INSERT INTO `__new_positions`("id", "user_id", "item_id", "position_schema_id", "data", "created_at", "updated_at") SELECT "id", "user_id", "item_id", "position_schema_id", "data", "created_at", "updated_at" FROM `positions`;--> statement-breakpoint
DROP TABLE `positions`;--> statement-breakpoint
ALTER TABLE `__new_positions` RENAME TO `positions`;--> statement-breakpoint
CREATE TABLE `__new_upload_files` (
	`id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`key` text NOT NULL,
	`filename` text NOT NULL,
	`content_type` text NOT NULL,
	`size` integer NOT NULL,
	`item_id` text,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`item_id`) REFERENCES `items`(`id`) ON UPDATE no action ON DELETE set null
);
--> statement-breakpoint
INSERT INTO `__new_upload_files`("id", "user_id", "key", "filename", "content_type", "size", "item_id", "created_at") SELECT "id", "user_id", "key", "filename", "content_type", "size", "item_id", "created_at" FROM `upload_files`;--> statement-breakpoint
DROP TABLE `upload_files`;--> statement-breakpoint
ALTER TABLE `__new_upload_files` RENAME TO `upload_files`;