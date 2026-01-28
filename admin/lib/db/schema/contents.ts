import { sqliteTable, text, integer } from "drizzle-orm/sqlite-core";
import { relations } from "drizzle-orm";
import { items } from "./items";

// Content JSON structure types
export interface FileContentData {
  title: string;
  description?: string;
  mime_type: string;
  size: number;
  file_path: string;
}

export interface ImageContentData extends FileContentData {
  preview_image_url?: string;
}

export interface VideoContentData extends ImageContentData {
  video_length: number;
  preview_video_url?: string;
}

export type ContentData = FileContentData | ImageContentData | VideoContentData;

export const contents = sqliteTable("contents", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  itemId: integer("item_id")
    .notNull()
    .references(() => items.id, { onDelete: "cascade" }),
  type: text("type", { enum: ["file", "image", "video"] }).notNull(),
  data: text("data", { mode: "json" }).notNull().$type<ContentData>(),
  createdAt: integer("created_at", { mode: "timestamp" })
    .notNull()
    .$defaultFn(() => new Date()),
  updatedAt: integer("updated_at", { mode: "timestamp" })
    .notNull()
    .$defaultFn(() => new Date()),
});

export const contentsRelations = relations(contents, ({ one }) => ({
  item: one(items, {
    fields: [contents.itemId],
    references: [items.id],
  }),
}));

export type Content = typeof contents.$inferSelect;
export type NewContent = typeof contents.$inferInsert;
