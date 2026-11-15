import { createHash, randomBytes } from "node:crypto";
import { ApiError } from "./errors";

export const MCP_SCOPES = ["storage:read", "storage:write"] as const;
export type McpScope = typeof MCP_SCOPES[number];
export const ACCESS_TOKEN_PREFIX = "storage_oauth_";
export const REFRESH_TOKEN_PREFIX = "storage_refresh_";
export const ACCESS_TOKEN_SECONDS = 3600;
export const GRANT_SECONDS = 30 * 24 * 3600;
export const LOGIN_SECONDS = 10 * 60;

export function secret(prefix = ""): string {
  return prefix + randomBytes(32).toString("base64url");
}

export function digest(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

export function challenge(verifier: string): string {
  return createHash("sha256").update(verifier).digest("base64url");
}

/** Trusted deployment configuration, never derived from Host or forwarded request headers. */
export function mcpResource(): string {
  const url = new URL(process.env.MCP_RESOURCE_URL || (process.env.NODE_ENV === "development" ? "http://localhost:3000/api/mcp" : "https://storage.rxlab.app/api/mcp"));
  const loopback = ["localhost", "127.0.0.1", "[::1]"].includes(url.hostname);
  if ((url.protocol !== "https:" && !(url.protocol === "http:" && loopback)) || url.username || url.password
    || url.pathname !== "/api/mcp" || url.search || url.hash) {
    throw new ApiError(503, "MCP_OAUTH_NOT_CONFIGURED", "MCP_RESOURCE_URL must be the HTTPS /api/mcp endpoint (HTTP is allowed on loopback).");
  }
  return url.href;
}

export function mcpOrigin(): string {
  return new URL(mcpResource()).origin;
}

export function oauthUrl(path: string): string {
  return `${mcpOrigin()}/api/mcp/oauth/${path}`;
}

export function resourceMetadata() {
  return { resource: mcpResource(), authorization_servers: [mcpOrigin()], scopes_supported: [...MCP_SCOPES], bearer_methods_supported: ["header"] };
}

export function authorizationMetadata() {
  return {
    issuer: mcpOrigin(),
    authorization_endpoint: oauthUrl("authorize"),
    token_endpoint: oauthUrl("token"),
    registration_endpoint: oauthUrl("register"),
    revocation_endpoint: oauthUrl("revoke"),
    response_types_supported: ["code"],
    grant_types_supported: ["authorization_code", "refresh_token"],
    token_endpoint_auth_methods_supported: ["none"],
    code_challenge_methods_supported: ["S256"],
    scopes_supported: [...MCP_SCOPES],
    authorization_response_iss_parameter_supported: true,
  };
}

export function authChallenge(scope: string = MCP_SCOPES.join(" "), error?: "invalid_token" | "insufficient_scope"): string {
  return `Bearer realm="storage", resource_metadata="${mcpOrigin()}/.well-known/oauth-protected-resource", scope="${scope}"`
    + (error ? `, error="${error}", error_description="${error === "invalid_token" ? "Sign in to RxStorage again" : "Approve the required RxStorage permissions"}"` : "");
}

export function toolScope(name: string): McpScope { return ["find_items", "read_item", "list_contents"].includes(name) ? "storage:read" : "storage:write"; }
export function securitySchemes(name: string) { return [{type: "oauth2", scopes: [toolScope(name)]}]; }
