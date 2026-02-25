import { sqliteTable, text, integer } from "drizzle-orm/sqlite-core";

export const accountDeletions = sqliteTable("account_deletions", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  userId: text("user_id").notNull(),
  userEmail: text("user_email"),
  scheduledAt: integer("scheduled_at", { mode: "timestamp" }).notNull(),
  qstashMessageId: text("qstash_message_id"),
  status: text("status", {
    enum: ["pending", "completed", "cancelled"],
  })
    .notNull()
    .default("pending"),
  createdAt: integer("created_at", { mode: "timestamp" })
    .notNull()
    .$defaultFn(() => new Date()),
  updatedAt: integer("updated_at", { mode: "timestamp" })
    .notNull()
    .$defaultFn(() => new Date()),
});

export type AccountDeletion = typeof accountDeletions.$inferSelect;
export type NewAccountDeletion = typeof accountDeletions.$inferInsert;
