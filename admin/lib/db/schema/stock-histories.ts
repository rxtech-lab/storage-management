import { sqliteTable, text, integer } from "drizzle-orm/sqlite-core";
import { relations } from "drizzle-orm";
import { nanoid } from "nanoid";
import { items } from "./items";

export const stockHistories = sqliteTable("stock_histories", {
  id: text("id")
    .primaryKey()
    .$defaultFn(() => nanoid()),
  userId: text("user_id").notNull(),
  itemId: text("item_id")
    .notNull()
    .references(() => items.id, { onDelete: "cascade" }),
  quantity: integer("quantity").notNull(),
  note: text("note"),
  createdAt: integer("created_at", { mode: "timestamp" })
    .notNull()
    .$defaultFn(() => new Date()),
});

export const stockHistoriesRelations = relations(stockHistories, ({ one }) => ({
  item: one(items, {
    fields: [stockHistories.itemId],
    references: [items.id],
  }),
}));

export type StockHistory = typeof stockHistories.$inferSelect;
export type NewStockHistory = typeof stockHistories.$inferInsert;
