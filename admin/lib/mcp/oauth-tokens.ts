import { and, eq, gt, isNull, lt, or, isNotNull } from "drizzle-orm";
type ApiPrincipal = { sub: string; clientId: string; scopes: string[] };
import { db as storageDb } from "@/lib/db";
type Database = typeof storageDb;
import { mcpOAuthCodes, mcpOAuthGrants, mcpOAuthRequests, mcpOAuthTokens } from "@/lib/db/schema";
import { ACCESS_TOKEN_PREFIX, ACCESS_TOKEN_SECONDS, challenge, digest, GRANT_SECONDS, mcpResource, REFRESH_TOKEN_PREFIX, secret } from "./oauth-config";

export class OAuthError extends Error {
  constructor(public code: string, message: string, public status = 400) { super(message); }
}

export type McpPrincipal = ApiPrincipal & { apiKeyId?: string };

export async function authenticateOAuthToken(db: Database, token: string, now = new Date()): Promise<McpPrincipal | null> {
  if (!token.startsWith(ACCESS_TOKEN_PREFIX) || token.length > 200) return null;
  const [row] = await db.select({ grant: mcpOAuthGrants, ownerId: mcpOAuthGrants.ownerId }).from(mcpOAuthTokens)
    .innerJoin(mcpOAuthGrants, eq(mcpOAuthGrants.id, mcpOAuthTokens.grantId))
    .where(and(eq(mcpOAuthTokens.hash, digest(token)), eq(mcpOAuthTokens.kind, "access"), gt(mcpOAuthTokens.expiresAt, now),
      gt(mcpOAuthGrants.expiresAt, now), isNull(mcpOAuthGrants.revokedAt), eq(mcpOAuthGrants.resource, mcpResource()))).limit(1);
  return row ? { sub: row.ownerId, clientId: row.grant.clientId, scopes: row.grant.scope.split(" ") } : null;
}

/** Every issuance rotates the refresh credential; consumed hashes remain for replay detection. */
async function issueTokens(tx: Parameters<Parameters<Database["transaction"]>[0]>[0], grant: typeof mcpOAuthGrants.$inferSelect, now: Date) {
  const access = secret(ACCESS_TOKEN_PREFIX);
  const refresh = secret(REFRESH_TOKEN_PREFIX);
  const expiresIn = Math.min(ACCESS_TOKEN_SECONDS, Math.floor((grant.expiresAt.getTime() - now.getTime()) / 1000));
  await tx.insert(mcpOAuthTokens).values([
    { hash: digest(access), grantId: grant.id, kind: "access", expiresAt: new Date(now.getTime() + expiresIn * 1000) },
    { hash: digest(refresh), grantId: grant.id, kind: "refresh", expiresAt: grant.expiresAt },
  ]);
  return { access_token: access, refresh_token: refresh, token_type: "Bearer", expires_in: expiresIn, scope: grant.scope };
}

export async function exchangeCode(db: Database, args: { code: string; clientId: string; redirectUri: string; verifier: string; resource: string }, now = new Date()) {
  const result = await db.transaction(async tx => {
    const [row] = await tx.select({ code: mcpOAuthCodes, grant: mcpOAuthGrants }).from(mcpOAuthCodes)
      .innerJoin(mcpOAuthGrants, eq(mcpOAuthGrants.id, mcpOAuthCodes.grantId))
      .where(eq(mcpOAuthCodes.hash, digest(args.code))).limit(1);
    if (!row || row.code.expiresAt <= now || row.grant.expiresAt <= now || row.grant.revokedAt
      || row.grant.clientId !== args.clientId || row.code.redirectUri !== args.redirectUri || row.grant.resource !== args.resource
      || !/^[A-Za-z0-9._~-]{43,128}$/.test(args.verifier) || challenge(args.verifier) !== row.code.challenge) {
      throw new OAuthError("invalid_grant", "The authorization code or PKCE verifier is invalid.");
    }
    if (row.code.usedAt) {
      await tx.update(mcpOAuthGrants).set({ revokedAt: now }).where(eq(mcpOAuthGrants.id, row.grant.id));
      return null;
    }
    const consumed = await tx.update(mcpOAuthCodes).set({ usedAt: now }).where(and(eq(mcpOAuthCodes.hash, row.code.hash), isNull(mcpOAuthCodes.usedAt))).returning();
    if (!consumed.length) throw new OAuthError("invalid_grant", "The authorization code has already been used.");
    return issueTokens(tx, row.grant, now);
  });
  if (!result) throw new OAuthError("invalid_grant", "The authorization code has already been used.");
  return result;
}

export async function exchangeRefresh(db: Database, args: { token: string; clientId: string; resource: string; scope?: string }, now = new Date()) {
  // Commit revocation before reporting replay; throwing inside the transaction would roll it back.
  const result = await db.transaction(async tx => {
    const [row] = await tx.select({ token: mcpOAuthTokens, grant: mcpOAuthGrants }).from(mcpOAuthTokens)
      .innerJoin(mcpOAuthGrants, eq(mcpOAuthGrants.id, mcpOAuthTokens.grantId))
      .where(and(eq(mcpOAuthTokens.hash, digest(args.token)), eq(mcpOAuthTokens.kind, "refresh"))).limit(1);
    if (!row || row.grant.clientId !== args.clientId || row.grant.resource !== args.resource
      || row.token.expiresAt <= now || row.grant.expiresAt <= now || row.grant.revokedAt) return null;
    if (row.token.usedAt) {
      await tx.update(mcpOAuthGrants).set({ revokedAt: now }).where(eq(mcpOAuthGrants.id, row.grant.id));
      return null;
    }
    if (args.scope && args.scope.split(" ").some(scope => !row.grant.scope.split(" ").includes(scope))) {
      throw new OAuthError("invalid_scope", "Refresh cannot expand the granted scopes.");
    }
    const scope = args.scope ?? row.grant.scope;
    if (scope !== row.grant.scope) await tx.update(mcpOAuthGrants).set({ scope }).where(eq(mcpOAuthGrants.id, row.grant.id));
    const consumed = await tx.update(mcpOAuthTokens).set({ usedAt: now })
      .where(and(eq(mcpOAuthTokens.hash, row.token.hash), isNull(mcpOAuthTokens.usedAt))).returning();
    if (!consumed.length) return null;
    return issueTokens(tx, { ...row.grant, scope }, now);
  });
  if (!result) throw new OAuthError("invalid_grant", "The refresh token is expired, revoked, or already used.");
  return result;
}

export async function revokeToken(db: Database, token: string, clientId: string, now = new Date()) {
  const [row] = await db.select({ grantId: mcpOAuthGrants.id }).from(mcpOAuthTokens)
    .innerJoin(mcpOAuthGrants, eq(mcpOAuthGrants.id, mcpOAuthTokens.grantId))
    .where(and(eq(mcpOAuthTokens.hash, digest(token)), eq(mcpOAuthGrants.clientId, clientId))).limit(1);
  if (row) await db.update(mcpOAuthGrants).set({ revokedAt: now }).where(eq(mcpOAuthGrants.id, row.grantId));
}

export function grantExpiry(now: Date): Date { return new Date(now.getTime() + GRANT_SECONDS * 1000); }

/** Retain consumed refresh hashes for the grant's lifetime, so replay can revoke its whole family. */
export async function cleanupOAuth(db: Database, now: Date) {
  await db.delete(mcpOAuthRequests).where(lt(mcpOAuthRequests.expiresAt, now));
  await db.delete(mcpOAuthCodes).where(lt(mcpOAuthCodes.expiresAt, now));
  await db.delete(mcpOAuthTokens).where(lt(mcpOAuthTokens.expiresAt, now));
  await db.delete(mcpOAuthGrants).where(or(lt(mcpOAuthGrants.expiresAt, now), isNotNull(mcpOAuthGrants.revokedAt)));
}
