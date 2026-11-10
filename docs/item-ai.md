# Item QR codes and AI drafts

New Item opens a menu with **Create using form** and **Create using AI**. Web uses a dedicated dialog; iOS and macOS use a sheet. The description's AI search button opens the same draft workflow with the form's current title, description, QR value, and images.

QR values can be entered directly or decoded from an image. iOS also supports camera scanning. Values are stored as `originalQrCode`; scanning does not navigate to the scanned URL.

AI accepts a description and up to five images. Attachments upload directly to presigned S3 URLs, then the draft endpoint receives only `file:` references. Native photo attachments are converted to JPEG. Web accepts JPEG, PNG, WebP, and GIF, up to 10 MB per image.

Web search is enabled by default and can be turned off. The review view shows editable title and description, source links, and optional category, author, and tag suggestions. Selected related records are created or reused when applying the draft. The item itself is saved only after submitting the item form. Existing item tags are preserved when adding AI suggestions.

## Configuration

The server uses Vercel AI Gateway with `ITEM_AI_MODEL` (default `openai/gpt-4.1-mini`). It uses the Gateway SDK's automatic authentication, including [Vercel OIDC](https://vercel.com/docs/ai-gateway/authentication-and-byok). There is no required API-key check. For local AI calls, pull Vercel environment credentials or optionally configure `AI_GATEWAY_API_KEY`.

Research uses Gateway's Perplexity search tool. Failed searches return an error so users can retry or disable web search.

## API

- `POST /api/v1/items/ai`: authenticated, validates ownership of uploaded images, returns `{ draft, sources }`, creates no records.
- `POST /api/v1/items/ai/relations`: authenticated, accepts the selected category/author names and tags, reuses only the current user's records, returns `{ categoryId, authorId, tagIds }`.
- Item create/update accept optional `tagIds` to add owned tags atomically with the item mutation.

Regenerate OpenAPI and native request types with `./scripts/admin-openapi-local.sh` before building native clients.

## Tests

`PLAYWRIGHT_PORT=3107 ./scripts/admin-e2e.sh e2e/items/create-item.spec.ts e2e/items/item-ai.spec.ts e2e/api/item-ai-relations.spec.ts` runs the browser and API coverage with isolated SQLite storage. AI responses and S3 transfers are mocked in browser tests; live model/search quality and real storage transfers require separate verification.
