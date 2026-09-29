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
CREATE INDEX `item_stocks_item_idx` ON `item_stocks` (`item_id`);
--> statement-breakpoint
CREATE INDEX `item_stocks_parent_idx` ON `item_stocks` (`parent_id`);
--> statement-breakpoint
ALTER TABLE `stock_histories` ADD `stock_id` text REFERENCES item_stocks(id) ON DELETE set null;
--> statement-breakpoint
ALTER TABLE `positions` ADD `stock_id` text REFERENCES item_stocks(id) ON DELETE cascade;
