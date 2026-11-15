# RxStorage MCP

The Streamable HTTP endpoint is `https://storage.rxlab.app/api/mcp`. In an MCP client, add that URL and choose OAuth. Discovery leads to registration, RxLab sign-in, and a dedicated consent page. The iOS app exposes the same URL under **Settings → MCP Server**, with a copy button and a list of active client authorizations. Open a client to disconnect it. These are active authorizations, not online-session indicators.

## Deployment

Apply the Drizzle schema (the existing build runs `db:push`) before serving the new endpoints. `0009_mcp_oauth_recycle_bin.sql` records the new OAuth tables and nullable `items.deleted_at` column. Do not apply it twice.

Set:

- `MCP_RESOURCE_URL`: canonical public endpoint, e.g. `https://storage.rxlab.app/api/mcp`. Defaults to localhost:3000 in development and that production URL otherwise. For local development explicitly use `http://localhost:3000/api/mcp` (or your local port).
- Existing `AUTH_CLIENT_ID`, `AUTH_CLIENT_SECRET`, `AUTH_ISSUER`, and `AUTH_SECRET`: MCP uses the existing Auth.js web sign-in by default. Keep the normal `/api/auth/callback/rxlab` redirect registered with RxAuth; no additional client or redirect registration is required.
- Optional `MCP_RXAUTH_CLIENT_ID` and `MCP_RXAUTH_CLIENT_SECRET`: set both only to use a dedicated RxAuth client. In that mode register the exact callback `https://storage.rxlab.app/api/mcp/oauth/callback` (or local equivalent). Leave both unset to use existing web sign-in.
- `AUTH_ISSUER`: the existing trusted RxAuth issuer, used for upstream login and userinfo validation.
- Existing S3 configuration for image upload and download signing.

The iOS Debug/Release API hosts continue to come from the existing xcconfig configuration. MCP management returns the canonical URL configured on that server.

## OAuth contract

Discovery endpoints:

- `/.well-known/oauth-protected-resource`
- `/.well-known/oauth-protected-resource/api/mcp`
- `/.well-known/oauth-authorization-server`

OAuth routes live under `/api/mcp/oauth`: `register`, `authorize`, `callback`, `consent`, `token`, and `revoke`. Public clients must use authorization code with S256 PKCE and the exact registered redirect URI. HTTPS callbacks, HTTP loopback callbacks, and native application callback schemes are supported. Codes and tokens are resource and client bound. Codes are single-use; refresh tokens rotate, and replay revokes the grant. Tokens are stored as SHA-256 hashes. Upstream RxAuth tokens are used only to establish identity, and never returned to agents.

Scopes are `storage:read` and `storage:write`. Consent explicitly lists permissions. An unauthenticated MCP POST returns 401 with a protected-resource discovery challenge. Browser consent is cookie, state, origin, and CSRF bound. Disconnecting a grant immediately invalidates its access and refresh credentials.

## Tools

| Tool | Scope | Behavior |
| --- | --- | --- |
| `find_items` | read | Search owned active items; limit/offset pagination |
| `read_item` | read | Read an owned active item, including signed image URLs |
| `list_contents` | read | List an item's attachments with signed references and pagination |
| `update_item` | write | Edit title, description, price, currency, images |
| `set_parent` | write | Move to an owned parent, or root with null; rejects ancestor cycles |
| `delete_item` | write | Soft delete into the recycle bin |
| `get_image_upload_url` | write | Return a presigned S3 PUT URL and file ID |

Image flow: request `get_image_upload_url` with filename, MIME type and byte count; PUT the image bytes directly to the returned S3 URL with the returned headers; then pass `file:{fileId}` in `update_item.images`. The update checks ownership and S3 object existence. `images` replaces the image array, so retain existing references when adding an image. No image bytes pass through the serverless application.

MCP tools access only the authenticated owner's active inventory. There is no MCP permanent-delete tool.

## Recycle bin

Item deletion from the app, web or MCP now sets `deleted_at` and preserves attachments. Deleted items disappear from item reads, lists, searches, QR matching and dashboard results. Children are not recursively deleted. **Settings → Recycle Bin** lists deleted items; open an item to restore or permanently delete it. **Clear All** permanently deletes all currently recycled items, with native confirmation and an action overlay. Surviving children of permanently deleted parents move to the root. Restore clears a missing or deleted parent relationship.

Authenticated management API:

- `GET /api/v1/mcp/clients`, `DELETE /api/v1/mcp/clients/{grantId}`
- `GET /api/v1/recycle-bin`, `DELETE /api/v1/recycle-bin`
- `POST /api/v1/recycle-bin/{itemId}` (restore)
- `DELETE /api/v1/recycle-bin/{itemId}` (permanent deletion)

All management operations enforce account ownership. Clearing the bin may partially complete if an individual deletion fails; refresh and retry.

## Verification

`bun run test:run lib/mcp/__tests__/security.test.ts` exercises PKCE/resource/client binding, replay revocation, ownership, parent cycles, soft deletion/restoration/purge and MCP tool permissions against SQLite and the SDK's in-memory transport. `e2e/api/mcp-management.spec.ts` checks actual HTTP discovery, registration validation and recycle-bin operations. Live RxAuth consent and S3 transfer require deployed credentials and are separate from these local checks.
