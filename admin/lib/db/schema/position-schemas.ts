import { sqliteTable, text, integer } from "drizzle-orm/sqlite-core";
import { nanoid } from "nanoid";

export const positionSchemas = sqliteTable("position_schemas", {
  id: text("id")
    .primaryKey()
    .$defaultFn(() => nanoid()),
  userId: text("user_id").notNull(),
  name: text("name").notNull(),
  schema: text("schema", { mode: "json" }).notNull().$type<object>(),
  createdAt: integer("created_at", { mode: "timestamp" })
    .notNull()
    .$defaultFn(() => new Date()),
  updatedAt: integer("updated_at", { mode: "timestamp" })
    .notNull()
    .$defaultFn(() => new Date()),
});

export type PositionSchema = typeof positionSchemas.$inferSelect;
export type NewPositionSchema = typeof positionSchemas.$inferInsert;
