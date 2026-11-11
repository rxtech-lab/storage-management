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

## Barcode lookup

`POST /api/v1/items/lookup` accepts `{ barcode, inventory?: boolean }` and requires authentication. It returns `{ barcode, itemUrl, result }`. By default it resolves existing inventory first using the QR scan endpoint's permission checks. An existing item returns `itemUrl`; an external match returns an editable `{ draft, sources }` in `result`; no match returns both as null. Lookup creates no records. Provider failures return 502 so users can retry.

ISBN-10/13 and EAN/UPC check digits are validated on the server. ISBNs in supported URL paths/query parameters and `ISBN:`/`urn:isbn:` text are extracted without fetching scanned URLs. Books use [Open Library](https://openlibrary.org/dev/docs/api/books), falling back to an exact ISBN match from [Google Books](https://developers.google.com/books/docs/v1/using). Products use [UPCitemdb](https://www.upcitemdb.com/api/), which is also the final fallback for books missing from the book catalogs. ISBN-10 is converted to ISBN-13 for retail lookup. Coverage and metadata quality depend on the providers. Successful provider responses are cached for 24 hours; each request has a seven-second timeout. UPCitemdb's default free endpoint allows 100 requests per day shared by the deployment. Set optional server-only `UPCITEMDB_API_KEY` to use its paid endpoint for larger usage. Optional `GOOGLE_BOOKS_API_KEY` uses your Google project quota instead of the anonymous Books API quota. Provider limit, timeout, and service failures are logged by provider name without scanned values or credentials, and shown as actionable errors if all fallbacks fail.

The iPhone/iPad global scanner opens existing inventory or a dedicated creation sheet with a details review. Camera and native image import recognize QR, EAN-13, EAN-8, UPC-E, and Code 128. Web image scanning uses ZXing. Item forms offer barcode lookup and show suggestions in a separate sheet/dialog; form lookups set `inventory: false` to research metadata for the current form. Users choose related suggestions and explicitly apply them before saving. Uploaded image handling remains direct to presigned S3 URLs; barcode lookup sends only the decoded text.

## Tests

`PLAYWRIGHT_PORT=3107 ./scripts/admin-e2e.sh e2e/items/create-item.spec.ts e2e/items/item-ai.spec.ts e2e/api/item-ai-relations.spec.ts` runs the browser and API coverage with isolated SQLite storage. AI responses and S3 transfers are mocked in browser tests; live model/search quality and real storage transfers require separate verification.
