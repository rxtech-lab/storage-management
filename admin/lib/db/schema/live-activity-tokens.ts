import { sqliteTable, text, integer, index } from "drizzle-orm/sqlite-core";

/**
 * An APNs Live Activity token registered by the iOS app. A `start` token is
 * the per-install push-to-start token used to start the ISO jobs Live
 * Activity remotely; an `update` token belongs to one running activity, which
 * lists all of the user's running jobs, and is used to update and end it.
 */
export const liveActivityTokens = sqliteTable(
  "live_activity_tokens",
  {
    token: text("token").primaryKey(),
    userId: text("user_id").notNull(),
    kind: text("kind", { enum: ["start", "update"] }).notNull(),
    environment: text("environment", { enum: ["sandbox", "production"] }).notNull(),
    // Last push sent with this token, used to throttle updates and repeated starts
    lastPushedAt: integer("last_pushed_at", { mode: "timestamp" }),
    createdAt: integer("created_at", { mode: "timestamp" })
      .notNull()
      .$defaultFn(() => new Date()),
    updatedAt: integer("updated_at", { mode: "timestamp" })
      .notNull()
      .$defaultFn(() => new Date()),
  },
  (table) => [index("live_activity_tokens_user_idx").on(table.userId)]
);

export type LiveActivityToken = typeof liveActivityTokens.$inferSelect;
export type NewLiveActivityToken = typeof liveActivityTokens.$inferInsert;
