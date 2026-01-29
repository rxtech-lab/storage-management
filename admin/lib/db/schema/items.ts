import { sqliteTable, text, integer, real } from "drizzle-orm/sqlite-core";
import { relations } from "drizzle-orm";
import { categories } from "./categories";
import { locations } from "./locations";
import { authors } from "./authors";

export const items = sqliteTable("items", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  userId: text("user_id").notNull(),
  title: text("title").notNull(),
  description: text("description"),
  originalQrCode: text("original_qr_code"),
  categoryId: integer("category_id").references(() => categories.id),
  locationId: integer("location_id").references(() => locations.id),
  authorId: integer("author_id").references(() => authors.id),
  parentId: integer("parent_id"),
  price: real("price"),
  currency: text("currency").default("USD"),
  visibility: text("visibility", { enum: ["public", "private"] })
    .notNull()
    .default("private"),
  images: text("images", { mode: "json" }).$type<string[]>().default([]),
  createdAt: integer("created_at", { mode: "timestamp" })
    .notNull()
    .$defaultFn(() => new Date()),
  updatedAt: integer("updated_at", { mode: "timestamp" })
    .notNull()
    .$defaultFn(() => new Date()),
});

export const itemsRelations = relations(items, ({ one, many }) => ({
  category: one(categories, {
    fields: [items.categoryId],
    references: [categories.id],
  }),
  location: one(locations, {
    fields: [items.locationId],
    references: [locations.id],
  }),
  author: one(authors, {
    fields: [items.authorId],
    references: [authors.id],
  }),
  parent: one(items, {
    fields: [items.parentId],
    references: [items.id],
    relationName: "parentChild",
  }),
  children: many(items, {
    relationName: "parentChild",
  }),
}));

export type Item = typeof items.$inferSelect;
export type NewItem = typeof items.$inferInsert;
