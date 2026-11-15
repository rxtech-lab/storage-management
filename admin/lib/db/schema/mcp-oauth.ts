import { sqliteTable, text, integer, index } from "drizzle-orm/sqlite-core";
import { sql } from "drizzle-orm";
const now = sql`(cast(unixepoch('subsecond') * 1000 as integer))`;
export const mcpOAuthClients = sqliteTable("mcp_oauth_clients", {
  id: text("id").primaryKey(),
  name: text("name").notNull(),
  redirectUris: text("redirect_uris", { mode: "json" }).$type<string[]>().notNull(),
  createdAt: integer("created_at", { mode: "timestamp_ms" }).notNull().default(now),
}, (table) => [index("mcp_oauth_clients_created_idx").on(table.createdAt)]);

/** Short-lived login/consent state. Upstream access and refresh tokens are never persisted. */
export const mcpOAuthRequests = sqliteTable("mcp_oauth_requests", {
  id: text("id").primaryKey(),
  stateHash: text("state_hash").notNull().unique(),
  clientId: text("client_id").notNull().references(() => mcpOAuthClients.id, { onDelete: "cascade" }),
  redirectUri: text("redirect_uri").notNull(),
  clientState: text("client_state"),
  challenge: text("challenge").notNull(),
  scope: text("scope").notNull(),
  upstreamVerifier: text("upstream_verifier").notNull(),
  loginClaimedAt: integer("login_claimed_at", { mode: "timestamp_ms" }),
  ownerId: text("owner_id"),
  consentHash: text("consent_hash"),
  expiresAt: integer("expires_at", { mode: "timestamp_ms" }).notNull(),
}, (table) => [index("mcp_oauth_requests_expiry_idx").on(table.expiresAt)]);

export const mcpOAuthGrants = sqliteTable("mcp_oauth_grants", {
  id: text("id").primaryKey(),
  ownerId: text("owner_id").notNull(),
  clientId: text("client_id").notNull().references(() => mcpOAuthClients.id, { onDelete: "cascade" }),
  resource: text("resource").notNull(),
  scope: text("scope").notNull(),
  revokedAt: integer("revoked_at", { mode: "timestamp_ms" }),
  expiresAt: integer("expires_at", { mode: "timestamp_ms" }).notNull(),
}, (table) => [index("mcp_oauth_grants_owner_idx").on(table.ownerId), index("mcp_oauth_grants_expiry_idx").on(table.expiresAt)]);

/** Codes and tokens are stored only as SHA-256 hashes. */
export const mcpOAuthCodes = sqliteTable("mcp_oauth_codes", {
  hash: text("hash").primaryKey(),
  grantId: text("grant_id").notNull().references(() => mcpOAuthGrants.id, { onDelete: "cascade" }),
  redirectUri: text("redirect_uri").notNull(),
  challenge: text("challenge").notNull(),
  usedAt: integer("used_at", { mode: "timestamp_ms" }),
  expiresAt: integer("expires_at", { mode: "timestamp_ms" }).notNull(),
}, (table) => [index("mcp_oauth_codes_expiry_idx").on(table.expiresAt)]);

export const mcpOAuthTokens = sqliteTable("mcp_oauth_tokens", {
  hash: text("hash").primaryKey(),
  grantId: text("grant_id").notNull().references(() => mcpOAuthGrants.id, { onDelete: "cascade" }),
  kind: text("kind", { enum: ["access", "refresh"] }).notNull(),
  usedAt: integer("used_at", { mode: "timestamp_ms" }),
  expiresAt: integer("expires_at", { mode: "timestamp_ms" }).notNull(),
}, (table) => [index("mcp_oauth_tokens_grant_idx").on(table.grantId), index("mcp_oauth_tokens_expiry_idx").on(table.expiresAt)]);
