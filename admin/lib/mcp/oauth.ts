import { and, eq, gt, isNull, lt, sql } from "drizzle-orm";
import { z } from "zod";
import { verifyBearerToken } from "@/lib/auth-helper";
import { auth } from "@/auth";
import { db } from "@/lib/db";
const getDatabase = () => db;
import { mcpOAuthClients, mcpOAuthCodes, mcpOAuthGrants, mcpOAuthRequests } from "@/lib/db/schema";
import { ApiError, noStoreJson } from "./errors";
import { challenge, digest, LOGIN_SECONDS, MCP_SCOPES, mcpOrigin, mcpResource, oauthUrl, secret } from "./oauth-config";
import { exchangeCode, exchangeRefresh, grantExpiry, OAuthError, revokeToken } from "./oauth-tokens";
import { renderConsentPage } from "./oauth-consent";

const MAX_BODY_BYTES = 16_384;
const FLOW_COOKIE_PREFIX = "storage_mcp_";

/** OAuth endpoints use RFC error envelopes and never log codes, tokens, or request bodies. */
export async function oauthResponse(action: () => Promise<Response>): Promise<Response> {
  try { return await action(); }
  catch (error) {
    if (error instanceof OAuthError) return noStoreJson({ error: error.code, error_description: error.message }, { status: error.status });
    if (error instanceof z.ZodError) return noStoreJson({ error: "invalid_request", error_description: "Invalid OAuth request parameters." }, { status: 400 });
    if (error instanceof ApiError && error.status === 503) return noStoreJson({ error: "temporarily_unavailable", error_description: error.message }, { status: 503 });
    console.error("[mcp-oauth] request failed");
    return noStoreJson({ error: "server_error", error_description: "Could not complete RxStorage authorization." }, { status: 500 });
  }
}

async function bodyText(request: Request, contentType: string): Promise<string> {
  if (request.headers.get("content-type")?.split(";", 1)[0].toLowerCase() !== contentType) {
    throw new OAuthError("invalid_request", `Content-Type must be ${contentType}.`, 415);
  }
  if (Number(request.headers.get("content-length") ?? 0) > MAX_BODY_BYTES) throw new OAuthError("invalid_request", "Request too large.", 413);
  const text = await request.text();
  if (Buffer.byteLength(text) > MAX_BODY_BYTES) throw new OAuthError("invalid_request", "Request too large.", 413);
  return text;
}

async function form(request: Request) {
  const params = new URLSearchParams(await bodyText(request, "application/x-www-form-urlencoded"));
  for (const name of params.keys()) if (params.getAll(name).length !== 1) throw new OAuthError("invalid_request", "Duplicate OAuth parameter.");
  return params;
}

function required(params: URLSearchParams, name: string): string {
  const value = params.get(name);
  if (!value || value.length > 4096 || params.getAll(name).length !== 1) throw new OAuthError("invalid_request", `${name} is required.`);
  return value;
}

function scopes(value: string): string {
  const items = [...new Set(value.trim().split(/\s+/))];
  if (!items.length || items.some(s => !MCP_SCOPES.includes(s as typeof MCP_SCOPES[number]))) {
    throw new OAuthError("invalid_scope", "Request storage:read and/or storage:write.");
  }
  return items.sort().join(" ");
}

function validateResource(value: string | null) {
  if (value !== mcpResource()) throw new OAuthError("invalid_target", "The resource must be the RxStorage MCP endpoint.");
  return value;
}

function upstreamConfig() {
  const clientId = process.env.MCP_RXAUTH_CLIENT_ID?.trim();
  const clientSecret = process.env.MCP_RXAUTH_CLIENT_SECRET?.trim();
  if (!clientId && !clientSecret) return null;
  if (!clientId || !clientSecret) throw new ApiError(503, "MCP_OAUTH_NOT_CONFIGURED", "Set both MCP_RXAUTH_CLIENT_ID and MCP_RXAUTH_CLIENT_SECRET, or remove both to use web sign-in.");
  return { clientId, clientSecret, issuer: process.env.AUTH_ISSUER!.replace(/\/$/, "") };
}

function redirect(uri: string, values: Record<string, string>, state: string | null) {
  const url = new URL(uri);
  for (const name of ["code", "error", "error_description", "state", "iss"]) url.searchParams.delete(name);
  for (const [name, value] of Object.entries(values)) url.searchParams.set(name, value);
  if (state !== null) url.searchParams.set("state", state);
  url.searchParams.set("iss", mcpOrigin());
  return new Response(null, { status: 302, headers: { location: url.href, "cache-control": "no-store", "referrer-policy": "no-referrer" } });
}

function cookieName(id: string) { return `${FLOW_COOKIE_PREFIX}${id}`; }
function cookieValue(request: Request, id: string): string | undefined {
  return request.headers.get("cookie")?.split(";").map(s => s.trim()).find(s => s.startsWith(`${cookieName(id)}=`))?.slice(cookieName(id).length + 1);
}
function setFlowCookie(response: Response, id: string, value: string, maxAge = LOGIN_SECONDS) {
  response.headers.append("set-cookie", `${cookieName(id)}=${value}; Path=/api/mcp/oauth; HttpOnly; SameSite=Lax; Max-Age=${maxAge}${mcpOrigin().startsWith("https:") ? "; Secure" : ""}`);
}

function validRedirect(value: string): boolean {
  try {
    const url = new URL(value);
    if (url.hash || url.username || url.password || /[\s;'"<>]/.test(value)) return false;
    if (url.protocol === "https:") return true;
    if (url.protocol === "http:") return ["127.0.0.1", "[::1]", "localhost"].includes(url.hostname);
    // Native MCP clients (including RxCode) return through their registered app scheme.
    return !["javascript:", "data:", "file:", "vbscript:", "blob:", "about:", "ftp:", "ws:", "wss:"].includes(url.protocol)
      && /^[a-z][a-z0-9+.-]*:$/.test(url.protocol);
  } catch { return false; }
}

const registrationSchema = z.object({
  client_name: z.string().trim().min(1).max(100).default("MCP agent"),
  redirect_uris: z.array(z.string().max(2048).refine(validRedirect)).min(1).max(10),
  token_endpoint_auth_method: z.literal("none").default("none"),
  grant_types: z.array(z.enum(["authorization_code", "refresh_token"])).min(1).default(["authorization_code", "refresh_token"]),
  response_types: z.array(z.literal("code")).min(1).default(["code"]),
  scope: z.string().max(100).optional(),
});

export async function registerClient(request: Request): Promise<Response> {
  const text = await bodyText(request, "application/json");
  let json: unknown;
  try { json = JSON.parse(text); } catch { throw new OAuthError("invalid_client_metadata", "Client metadata must be JSON."); }
  const parsed = registrationSchema.safeParse(json);
  if (!parsed.success) throw new OAuthError("invalid_client_metadata", "Use HTTPS, loopback or native app redirect URIs and public authorization-code clients.");
  const metadata = parsed.data;
  if (!metadata.grant_types.includes("authorization_code")) throw new OAuthError("invalid_client_metadata", "The authorization_code grant is required.");
  const scope = scopes(metadata.scope ?? MCP_SCOPES.join(" "));
  const id = `storage-client-${crypto.randomUUID()}`;
  await getDatabase().transaction(async tx => {
    // Shared across serverless instances; bound anonymous DCR database writes.
    const [{ count }] = await tx.select({ count: sql<number>`count(*)` }).from(mcpOAuthClients)
      .where(gt(mcpOAuthClients.createdAt, new Date(Date.now() - 60_000)));
    if (count >= 60) throw new OAuthError("temporarily_unavailable", "Too many client registrations. Try again in a minute.", 429);
    await tx.insert(mcpOAuthClients).values({ id, name: metadata.client_name, redirectUris: [...new Set(metadata.redirect_uris)] });
  });
  return noStoreJson({ ...metadata, grant_types: ["authorization_code", "refresh_token"], scope, client_id: id,
    client_id_issued_at: Math.floor(Date.now() / 1000) }, { status: 201 });
}

export async function authorize(request: Request): Promise<Response> {
  const params = new URL(request.url).searchParams;
  const clientId = required(params, "client_id");
  const redirectUri = required(params, "redirect_uri");
  const [client] = await getDatabase().select().from(mcpOAuthClients).where(eq(mcpOAuthClients.id, clientId)).limit(1);
  // Never redirect to a URI until it has been matched to a registered client.
  if (!client || !client.redirectUris.includes(redirectUri)) throw new OAuthError("invalid_request", "The client or redirect URI is not registered.");
  const clientState = params.get("state");
  if (clientState !== null && (clientState.length > 4096 || params.getAll("state").length !== 1)) throw new OAuthError("invalid_request", "Invalid state.");
  try {
    if (required(params, "response_type") !== "code") throw new OAuthError("unsupported_response_type", "Only authorization code is supported.");
    if (required(params, "code_challenge_method") !== "S256") throw new OAuthError("invalid_request", "S256 PKCE is required.");
    const codeChallenge = required(params, "code_challenge");
    if (!/^[A-Za-z0-9_-]{43}$/.test(codeChallenge)) throw new OAuthError("invalid_request", "Invalid PKCE challenge.");
    validateResource(required(params, "resource"));
    const scope = scopes(params.has("scope") ? required(params, "scope") : "storage:read");
    const upstream = upstreamConfig();
    const state = secret();
    const verifier = upstream ? secret() : "";
    const id = crypto.randomUUID();
    const db = getDatabase();
    // Also retire abandoned login state; it never becomes a grant without explicit consent.
    await db.delete(mcpOAuthRequests).where(lt(mcpOAuthRequests.expiresAt, new Date()));
    await db.insert(mcpOAuthRequests).values({ id, stateHash: digest(state), clientId, redirectUri, clientState,
      challenge: codeChallenge, scope, upstreamVerifier: verifier, expiresAt: new Date(Date.now() + LOGIN_SECONDS * 1000) });
    if (!upstream) {
      // Reuse the existing Auth.js client and its registered callback. The MCP
      // callback checks the authenticated browser session before offering consent.
      const resume = new URL(oauthUrl("callback"));
      resume.searchParams.set("state", state);
      const response = new Response(null, { status: 302, headers: { location: resume.href, "cache-control": "no-store", "referrer-policy": "no-referrer" } });
      setFlowCookie(response, id, state);
      return response;
    }
    const login = new URL(`${upstream.issuer}/api/oauth/authorize`);
    for (const [name, value] of Object.entries({ client_id: upstream.clientId, redirect_uri: oauthUrl("callback"), response_type: "code",
      scope: "openid profile email", state, code_challenge: challenge(verifier), code_challenge_method: "S256" })) login.searchParams.set(name, value);
    const response = new Response(null, { status: 302, headers: { location: login.href, "cache-control": "no-store", "referrer-policy": "no-referrer" } });
    setFlowCookie(response, id, state);
    return response;
  } catch (error) {
    if (error instanceof OAuthError) return redirect(redirectUri, { error: error.code, error_description: error.message }, clientState);
    throw error;
  }
}

export async function callback(request: Request): Promise<Response> {
  const params = new URL(request.url).searchParams;
  const state = required(params, "state");
  const db = getDatabase();
  const [pending] = await db.select().from(mcpOAuthRequests).where(eq(mcpOAuthRequests.stateHash, digest(state))).limit(1);
  if (!pending || pending.expiresAt <= new Date() || pending.loginClaimedAt || cookieValue(request, pending.id) !== state) {
    throw new OAuthError("invalid_request", "The sign-in request is expired or belongs to another browser.");
  }
  // An empty upstream verifier marks a flow using the existing web login.
  // Read the browser session directly; bearer tokens cannot authorize consent.
  const browserSession = pending.upstreamVerifier === "" ? await auth() : null;
  if (pending.upstreamVerifier === "" && !browserSession?.user?.id) {
    const login = new URL("/login", mcpOrigin());
    const resume = new URL(oauthUrl("callback"));
    resume.searchParams.set("state", state);
    login.searchParams.set("callbackUrl", resume.href);
    return new Response(null, { status: 302, headers: { location: login.href, "cache-control": "no-store", "referrer-policy": "no-referrer" } });
  }
  const [claimed] = await db.update(mcpOAuthRequests).set({ loginClaimedAt: new Date() })
    .where(and(eq(mcpOAuthRequests.id, pending.id), isNull(mcpOAuthRequests.loginClaimedAt))).returning();
  if (!claimed) throw new OAuthError("invalid_request", "This sign-in callback has already been used.");
  let ownerId: string;
  if (pending.upstreamVerifier === "") {
    ownerId = browserSession!.user.id;
  } else {
    const upstream = upstreamConfig();
    if (!upstream) throw new OAuthError("temporarily_unavailable", "The dedicated OAuth configuration changed. Start sign-in again.", 503);
    // RxAuth currently omits iss. If it starts supplying it, require an exact issuer match.
    if (params.has("iss") && params.get("iss") !== upstream.issuer) throw new OAuthError("invalid_request", "Unexpected sign-in issuer.");
    if (params.has("error")) {
      const response = redirect(pending.redirectUri, { error: "access_denied", error_description: "RxStorage sign-in was cancelled." }, pending.clientState);
      await db.delete(mcpOAuthRequests).where(eq(mcpOAuthRequests.id, pending.id));
      setFlowCookie(response, pending.id, "", 0);
      return response;
    }
    const code = required(params, "code");
    const tokenResponse = await fetch(`${upstream.issuer}/api/oauth/token`, {
      method: "POST", redirect: "error", cache: "no-store", signal: AbortSignal.timeout(15_000),
      headers: { "content-type": "application/x-www-form-urlencoded", accept: "application/json" },
      body: new URLSearchParams({ grant_type: "authorization_code", code, client_id: upstream.clientId, client_secret: upstream.clientSecret,
        redirect_uri: oauthUrl("callback"), code_verifier: pending.upstreamVerifier }),
    });
    if (!tokenResponse.ok) throw new OAuthError("invalid_grant", "RxStorage sign-in could not be verified. Start again.");
    const tokens = z.object({ access_token: z.string().min(1).max(16384) }).parse(await tokenResponse.json());
    // This upstream token proves login only. It is never returned to an MCP client or accepted by /api/mcp.
    const session = await verifyBearerToken(tokens.access_token);
    if (!session?.user?.id || session.user.id === "unknown") throw new OAuthError("invalid_grant", "Sign-in could not be verified.");
    ownerId = session.user.id;
  }
  // The callback already proved possession of this flow's HttpOnly cookie. Keep its
  // value across the redirect instead of requiring a second cookie handoff to succeed.
  // Consent gets a fresh window even when sign-in used most of the login deadline.
  await db.update(mcpOAuthRequests).set({ ownerId, consentHash: digest(state), upstreamVerifier: "",
    expiresAt: new Date(Date.now() + LOGIN_SECONDS * 1000) }).where(eq(mcpOAuthRequests.id, pending.id));
  const response = new Response(null, { status: 302, headers: { location: `${oauthUrl("consent")}?request=${pending.id}`, "cache-control": "no-store" } });
  setFlowCookie(response, pending.id, state);
  return response;
}

async function consentRequest(request: Request, id: string) {
  const [row] = await getDatabase().select({ flow: mcpOAuthRequests, client: mcpOAuthClients }).from(mcpOAuthRequests)
    .innerJoin(mcpOAuthClients, eq(mcpOAuthClients.id, mcpOAuthRequests.clientId))
    .where(and(eq(mcpOAuthRequests.id, id), gt(mcpOAuthRequests.expiresAt, new Date()))).limit(1);
  const cookie = cookieValue(request, id);
  if (!row?.flow.ownerId || !row.flow.consentHash || !cookie || digest(cookie) !== row.flow.consentHash) {
    throw new OAuthError("invalid_request", "The consent request is expired or belongs to another browser.");
  }
  return { ...row, cookie };
}

export async function consentPage(request: Request): Promise<Response> {
  const id = required(new URL(request.url).searchParams, "request");
  const { flow, client, cookie } = await consentRequest(request, id);
  const html = renderConsentPage({ clientName: client.name, redirectUri: flow.redirectUri, scope: flow.scope,
    requestId: id, csrf: cookie, action: oauthUrl("consent"), accountName: "RxStorage account", accountEmail: null });
  // `no-referrer` makes native form POSTs send Origin: null. Preserve the origin for this
  // same-origin submission while suppressing referrers to the external agent callback.
  return new Response(html, { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store", "referrer-policy": "same-origin",
    // Do not constrain form-action: browsers apply it to the entire redirect chain,
    // including the agent's redirects after its registered callback. The form action
    // is fixed by us; approval validates Origin, CSRF and the exact stored callback.
    "content-security-policy": "default-src 'none'; style-src 'unsafe-inline'; frame-ancestors 'none'; base-uri 'none'", "x-content-type-options": "nosniff" } });
}

export async function approveConsent(request: Request): Promise<Response> {
  if (request.headers.get("origin") !== mcpOrigin()) throw new OAuthError("invalid_request", "Consent must be submitted from RxStorage.", 403);
  const params = await form(request);
  const id = required(params, "request");
  const { flow, cookie } = await consentRequest(request, id);
  if (required(params, "csrf") !== cookie) throw new OAuthError("invalid_request", "Invalid consent verification.", 403);
  const decision = required(params, "decision");
  if (!["allow", "deny"].includes(decision)) throw new OAuthError("invalid_request", "Choose whether to allow access.");
  const now = new Date();
  const code = secret();
  const db = getDatabase();
  await db.transaction(async tx => {
    const consumed = await tx.delete(mcpOAuthRequests).where(and(eq(mcpOAuthRequests.id, id), eq(mcpOAuthRequests.consentHash, digest(cookie)), gt(mcpOAuthRequests.expiresAt, now))).returning();
    if (!consumed.length) throw new OAuthError("invalid_request", "This consent request has already been used.");
    if (decision === "allow") {
      const grantId = crypto.randomUUID();
      await tx.insert(mcpOAuthGrants).values({ id: grantId, ownerId: flow.ownerId!, clientId: flow.clientId, resource: mcpResource(), scope: flow.scope, expiresAt: grantExpiry(now) });
      await tx.insert(mcpOAuthCodes).values({ hash: digest(code), grantId, redirectUri: flow.redirectUri, challenge: flow.challenge, expiresAt: new Date(now.getTime() + 60_000) });
    }
  });
  const response = redirect(flow.redirectUri, decision === "allow" ? { code } : { error: "access_denied", error_description: "RxStorage access was declined." }, flow.clientState);
  setFlowCookie(response, id, "", 0);
  return response;
}

export async function token(request: Request): Promise<Response> {
  const params = await form(request);
  const clientId = required(params, "client_id");
  const resource = validateResource(required(params, "resource"));
  const db = getDatabase();
  const [client] = await db.select().from(mcpOAuthClients).where(eq(mcpOAuthClients.id, clientId)).limit(1);
  if (!client || request.headers.has("authorization") || params.has("client_secret")) throw new OAuthError("invalid_client", "Use the registered public client with PKCE.", 401);
  const grantType = required(params, "grant_type");
  const result = grantType === "authorization_code"
    ? await exchangeCode(db, { code: required(params, "code"), clientId, redirectUri: required(params, "redirect_uri"), verifier: required(params, "code_verifier"), resource })
    : grantType === "refresh_token"
      ? await exchangeRefresh(db, { token: required(params, "refresh_token"), clientId, resource, scope: params.has("scope") ? scopes(required(params, "scope")) : undefined })
      : (() => { throw new OAuthError("unsupported_grant_type", "Use authorization_code or refresh_token."); })();
  return noStoreJson(result, { headers: { pragma: "no-cache" } });
}

export async function revoke(request: Request): Promise<Response> {
  const params = await form(request);
  if (request.headers.has("authorization") || params.has("client_secret")) throw new OAuthError("invalid_client", "Use the registered public client.", 401);
  await revokeToken(getDatabase(), required(params, "token"), required(params, "client_id"));
  return new Response(null, { status: 200, headers: { "cache-control": "no-store" } });
}
