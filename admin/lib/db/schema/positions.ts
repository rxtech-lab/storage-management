import { sqliteTable, text, integer } from "drizzle-orm/sqlite-core";
import { relations } from "drizzle-orm";
import { nanoid } from "nanoid";
import { items } from "./items";
import { positionSchemas } from "./position-schemas";

export const positions = sqliteTable("positions", {
  id: text("id")
    .primaryKey()
    .$defaultFn(() => nanoid()),
  userId: text("user_id").notNull(),
  itemId: text("item_id")
    .notNull()
    .references(() => items.id, { onDelete: "cascade" }),
  positionSchemaId: text("position_schema_id")
    .notNull()
    .references(() => positionSchemas.id),
  data: text("data", { mode: "json" }).notNull().$type<Record<string, unknown>>(),
  createdAt: integer("created_at", { mode: "timestamp" })
    .notNull()
    .$defaultFn(() => new Date()),
  updatedAt: integer("updated_at", { mode: "timestamp" })
    .notNull()
    .$defaultFn(() => new Date()),
});

export const positionsRelations = relations(positions, ({ one }) => ({
  item: one(items, {
    fields: [positions.itemId],
    references: [items.id],
  }),
  positionSchema: one(positionSchemas, {
    fields: [positions.positionSchemaId],
    references: [positionSchemas.id],
  }),
}));

export type Position = typeof positions.$inferSelect;
export type NewPosition = typeof positions.$inferInsert;
