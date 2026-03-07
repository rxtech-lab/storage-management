import { sqliteTable, text, integer, unique } from "drizzle-orm/sqlite-core";
import { relations } from "drizzle-orm";
import { nanoid } from "nanoid";
import { items } from "./items";
import { tags } from "./tags";

export const itemTags = sqliteTable(
  "item_tags",
  {
    id: text("id")
      .primaryKey()
      .$defaultFn(() => nanoid()),
    itemId: text("item_id")
      .notNull()
      .references(() => items.id, { onDelete: "cascade" }),
    tagId: text("tag_id")
      .notNull()
      .references(() => tags.id, { onDelete: "cascade" }),
    createdAt: integer("created_at", { mode: "timestamp" })
      .notNull()
      .$defaultFn(() => new Date()),
  },
  (table) => [unique().on(table.itemId, table.tagId)]
);

export const itemTagsRelations = relations(itemTags, ({ one }) => ({
  item: one(items, {
    fields: [itemTags.itemId],
    references: [items.id],
  }),
  tag: one(tags, {
    fields: [itemTags.tagId],
    references: [tags.id],
  }),
}));

export type ItemTag = typeof itemTags.$inferSelect;
export type NewItemTag = typeof itemTags.$inferInsert;
