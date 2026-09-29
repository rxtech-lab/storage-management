import { sqliteTable, text, integer, index } from "drizzle-orm/sqlite-core";

/**
 * An APNs device token registered by the iOS or macOS app so the server can
 * push notifications, e.g. when an ISO job finishes. The token is the primary
 * key because APNs tokens are unique per app install.
 */
export const deviceTokens = sqliteTable(
  "device_tokens",
  {
    token: text("token").primaryKey(),
    userId: text("user_id").notNull(),
    platform: text("platform", { enum: ["ios", "macos"] }).notNull(),
    environment: text("environment", { enum: ["sandbox", "production"] }).notNull(),
    createdAt: integer("created_at", { mode: "timestamp" })
      .notNull()
      .$defaultFn(() => new Date()),
    updatedAt: integer("updated_at", { mode: "timestamp" })
      .notNull()
      .$defaultFn(() => new Date()),
  },
  (table) => [index("device_tokens_user_idx").on(table.userId)]
);

export type DeviceToken = typeof deviceTokens.$inferSelect;
export type NewDeviceToken = typeof deviceTokens.$inferInsert;
