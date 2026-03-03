import { sqliteTable, text, integer, real } from "drizzle-orm/sqlite-core";
import { nanoid } from "nanoid";

export const locations = sqliteTable("locations", {
  id: text("id")
    .primaryKey()
    .$defaultFn(() => nanoid()),
  userId: text("user_id").notNull(),
  title: text("title").notNull(),
  latitude: real("latitude").notNull(),
  longitude: real("longitude").notNull(),
  createdAt: integer("created_at", { mode: "timestamp" })
    .notNull()
    .$defaultFn(() => new Date()),
  updatedAt: integer("updated_at", { mode: "timestamp" })
    .notNull()
    .$defaultFn(() => new Date()),
});

export type Location = typeof locations.$inferSelect;
export type NewLocation = typeof locations.$inferInsert;
