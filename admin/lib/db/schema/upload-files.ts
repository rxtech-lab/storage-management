import { sqliteTable, text, integer } from "drizzle-orm/sqlite-core";
import { relations } from "drizzle-orm";
import { items } from "./items";

export const uploadFiles = sqliteTable("upload_files", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  userId: text("user_id").notNull(),
  key: text("key").notNull(), // S3 object key
  filename: text("filename").notNull(),
  contentType: text("content_type").notNull(),
  size: integer("size").notNull(), // bytes
  itemId: integer("item_id").references(() => items.id, { onDelete: "set null" }),
  createdAt: integer("created_at", { mode: "timestamp" })
    .notNull()
    .$defaultFn(() => new Date()),
});

export const uploadFilesRelations = relations(uploadFiles, ({ one }) => ({
  item: one(items, {
    fields: [uploadFiles.itemId],
    references: [items.id],
  }),
}));

export type UploadFile = typeof uploadFiles.$inferSelect;
export type NewUploadFile = typeof uploadFiles.$inferInsert;
