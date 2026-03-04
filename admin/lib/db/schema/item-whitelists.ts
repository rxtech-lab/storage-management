import { sqliteTable, text, integer } from "drizzle-orm/sqlite-core";
import { relations } from "drizzle-orm";
import { nanoid } from "nanoid";
import { items } from "./items";

export const itemWhitelists = sqliteTable("item_whitelists", {
  id: text("id")
    .primaryKey()
    .$defaultFn(() => nanoid()),
  itemId: text("item_id")
    .notNull()
    .references(() => items.id, { onDelete: "cascade" }),
  email: text("email").notNull(),
  createdAt: integer("created_at", { mode: "timestamp" })
    .notNull()
    .$defaultFn(() => new Date()),
});

export const itemWhitelistsRelations = relations(itemWhitelists, ({ one }) => ({
  item: one(items, {
    fields: [itemWhitelists.itemId],
    references: [items.id],
  }),
}));

export type ItemWhitelist = typeof itemWhitelists.$inferSelect;
export type NewItemWhitelist = typeof itemWhitelists.$inferInsert;
