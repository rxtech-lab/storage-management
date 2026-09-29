import { sqliteTable, text, integer, index } from "drizzle-orm/sqlite-core";
import { relations } from "drizzle-orm";
import { nanoid } from "nanoid";
import { items } from "./items";
import { locations } from "./locations";

/**
 * A stock placement holds some units of an item somewhere other than the
 * item's main placement (the item row's own parent/location/positions/images).
 * Its quantity is the sum of stock_histories rows pointing at it, so units
 * without a stock_id always belong to the main placement.
 */
export const itemStocks = sqliteTable(
  "item_stocks",
  {
    id: text("id")
      .primaryKey()
      .$defaultFn(() => nanoid()),
    userId: text("user_id").notNull(),
    itemId: text("item_id")
      .notNull()
      .references(() => items.id, { onDelete: "cascade" }),
    parentId: text("parent_id"),
    locationId: text("location_id").references(() => locations.id),
    images: text("images", { mode: "json" }).$type<string[]>().default([]),
    note: text("note"),
    createdAt: integer("created_at", { mode: "timestamp" })
      .notNull()
      .$defaultFn(() => new Date()),
    updatedAt: integer("updated_at", { mode: "timestamp" })
      .notNull()
      .$defaultFn(() => new Date()),
  },
  (table) => [
    index("item_stocks_item_idx").on(table.itemId),
    index("item_stocks_parent_idx").on(table.parentId),
  ],
);

export const itemStocksRelations = relations(itemStocks, ({ one }) => ({
  item: one(items, {
    fields: [itemStocks.itemId],
    references: [items.id],
  }),
  location: one(locations, {
    fields: [itemStocks.locationId],
    references: [locations.id],
  }),
}));

export type ItemStock = typeof itemStocks.$inferSelect;
export type NewItemStock = typeof itemStocks.$inferInsert;
