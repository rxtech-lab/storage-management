import { sqliteTable, text, integer } from "drizzle-orm/sqlite-core";
import { relations } from "drizzle-orm";
import { nanoid } from "nanoid";
import { items } from "./items";
import { itemStocks } from "./item-stocks";

export const stockHistories = sqliteTable("stock_histories", {
  id: text("id")
    .primaryKey()
    .$defaultFn(() => nanoid()),
  userId: text("user_id").notNull(),
  itemId: text("item_id")
    .notNull()
    .references(() => items.id, { onDelete: "cascade" }),
  // Placement the units belong to; null means the item's main placement
  stockId: text("stock_id").references(() => itemStocks.id, { onDelete: "set null" }),
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
  stock: one(itemStocks, {
    fields: [stockHistories.stockId],
    references: [itemStocks.id],
  }),
}));

export type StockHistory = typeof stockHistories.$inferSelect;
export type NewStockHistory = typeof stockHistories.$inferInsert;
