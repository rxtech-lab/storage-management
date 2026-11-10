import { z } from "zod";
import { ItemAIResponseSchema, type ItemAIResponse } from "./schemas/item-ai";

// Never fetch scanned URLs. Extract only recognized identifiers and validate their check digit.
export function normalizeBarcode(raw: string): { code: string; book: boolean } | null {
  let input = raw.trim();
  if (/^https?:\/\//i.test(input)) {
    try {
      const url = new URL(input);
      input = url.searchParams.get("isbn") ?? url.searchParams.get("ISBN") ?? url.pathname.split("/").filter(Boolean).pop() ?? "";
    } catch { return null; }
  }
  const code = input.replace(/^urn:isbn:|^ISBN(?:-1[03])?:?\s*/i, "").replace(/[\s-]/g, "").toUpperCase();
  if (/^\d{9}[\dX]$/.test(code)) {
    const sum = [...code].reduce((n, c, i) => n + (c === "X" ? 10 : Number(c)) * (10 - i), 0);
    return sum % 11 === 0 ? { code, book: true } : null;
  }
  if (!/^(?:\d{8}|\d{12}|\d{13}|\d{14})$/.test(code)) return null;
  const sum = [...code].reverse().reduce((n, c, i) => n + Number(c) * (i % 2 ? 3 : 1), 0);
  if (sum % 10 !== 0) return null;
  return { code, book: code.length === 13 && /^(978|979)/.test(code) };
}

export class BarcodeProviderError extends Error {}

const named = z.object({ name: z.string() });
const openBook = z.object({ title: z.string().min(1), subtitle: z.string().optional(), authors: z.array(named).optional(), publishers: z.array(named).optional(), publish_date: z.string().optional(), number_of_pages: z.number().optional() });
const googleBook = z.object({ title: z.string().min(1), subtitle: z.string().optional(), authors: z.array(z.string()).optional(), publisher: z.string().optional(), publishedDate: z.string().optional(), description: z.string().optional(), industryIdentifiers: z.array(z.object({ identifier: z.string() })).optional() });
const product = z.object({ title: z.string().min(1), description: z.string().optional(), brand: z.string().optional(), model: z.string().optional(), category: z.string().optional(), upc: z.string().optional(), ean: z.string().optional() });

export async function lookupBarcode(raw: string, signal?: AbortSignal): Promise<ItemAIResponse | null> {
  const barcode = normalizeBarcode(raw);
  if (!barcode) return null;
  const failures: string[] = [];
  function fail(provider: string, reason: string) {
    failures.push(`${provider}: ${reason}`);
    // Do not log URLs, API keys, scanned values, or provider response bodies.
    console.warn("Barcode provider failed", { provider, reason });
  }
  async function json(provider: string, url: string, headers: Record<string, string> = {}): Promise<unknown> {
    try {
      const response = await fetch(url, {
        headers: { Accept: "application/json", "User-Agent": "RxStorage/1.0 (https://storage.rxlab.app)", ...headers },
        signal: signal ? AbortSignal.any([signal, AbortSignal.timeout(7000)]) : AbortSignal.timeout(7000),
        next: { revalidate: 86400 },
      });
      if (response.status === 404) return null;
      if (!response.ok) {
        fail(provider, response.status === 429 ? "lookup limit reached" : `service returned HTTP ${response.status}`);
        return null;
      }
      return await response.json();
    } catch (error) {
      if (signal?.aborted) throw error;
      fail(provider, error instanceof Error && ["TimeoutError", "AbortError"].includes(error.name) ? "request timed out" : "could not reach service or read its response");
      return null;
    }
  }
  function draft(title: string, description: string, author: string | null, category: string | null, source: string, url: string): ItemAIResponse {
    return ItemAIResponseSchema.parse({ draft: { title: title.slice(0, 500), description: description.slice(0, 8000), author: author?.slice(0, 100) || null, category: category?.slice(0, 100) || null, tags: [], originalQrCode: raw }, sources: [{ title: source, url }] });
  }
  const { code, book } = barcode;
  if (book) {
    const data = await json("Open Library", `https://openlibrary.org/api/books?bibkeys=ISBN:${code}&format=json&jscmd=data`);
    const books = z.record(openBook).safeParse(data);
    const found = books.success ? books.data[`ISBN:${code}`] : undefined;
    if (data && !books.success) fail("Open Library", "invalid catalog response");
    if (found) {
      return draft(found.title, [found.subtitle, found.authors?.map(a => a.name).join(", "), found.publishers?.map(p => p.name).join(", "), found.publish_date, found.number_of_pages ? `${found.number_of_pages} pages` : null, `ISBN: ${code}`].filter(Boolean).join("\n"), found.authors?.map(a => a.name).join(", ") ?? null, "Books", "Open Library", `https://openlibrary.org/isbn/${code}`);
    }
    const googleUrl = new URL("https://www.googleapis.com/books/v1/volumes");
    googleUrl.searchParams.set("q", `isbn:${code}`);
    if (process.env.GOOGLE_BOOKS_API_KEY) googleUrl.searchParams.set("key", process.env.GOOGLE_BOOKS_API_KEY);
    const google = await json("Google Books", googleUrl.toString());
    const volumes = z.object({ items: z.array(z.object({ volumeInfo: googleBook })).optional() }).safeParse(google);
    if (google && !volumes.success) fail("Google Books", "invalid catalog response");
    // Search may return unrelated editions: require an exact, validated ISBN match.
    const volume = volumes.success ? volumes.data.items?.find(v => v.volumeInfo.industryIdentifiers?.some(id => {
      const candidate = normalizeBarcode(id.identifier);
      return candidate && isbn13(candidate.code) === isbn13(code);
    }))?.volumeInfo : undefined;
    if (volume) return draft(volume.title, [volume.subtitle, volume.description?.replace(/<[^>]*>/g, ""), volume.publisher, volume.publishedDate, `ISBN: ${code}`].filter(Boolean).join("\n"), volume.authors?.join(", ") ?? null, "Books", "Google Books", `https://books.google.com/books?vid=ISBN${code}`);
  }
  // Retail catalogs also carry books that Open Library/Google Books may not index,
  // including regional editions. Keep exact identifier matching for this fallback.
  {
    const productCode = book ? isbn13(code) : code;
    const key = process.env.UPCITEMDB_API_KEY;
    const data = await json("UPCitemdb", `https://api.upcitemdb.com/prod/${key ? "v1" : "trial"}/lookup?upc=${productCode}`, key ? { user_key: key, key_type: "3scale" } : {});
    const products = z.object({ code: z.literal("OK"), items: z.array(product) }).safeParse(data);
    if (data && !products.success) fail("UPCitemdb", "invalid catalog response");
    const found = products.success ? products.data.items.find(p => [p.upc, p.ean].some(id => id && id.padStart(14, "0") === productCode.padStart(14, "0"))) : undefined;
    if (found) return draft(found.title, [found.description, found.brand ? `Brand: ${found.brand}` : null, found.model ? `Model: ${found.model}` : null, `Barcode: ${code}`].filter(Boolean).join("\n"), null, book ? "Books" : found.category ?? null, "UPCitemdb", `https://www.upcitemdb.com/upc/${productCode}`);
  }
  if (failures.length) throw new BarcodeProviderError(`No matching details could be retrieved. ${failures.join("; ")}. Try again later or enter the details manually.`);
  return null;
}

function isbn13(code: string): string {
  if (code.length !== 10) return code;
  const base = "978" + code.slice(0, 9);
  const sum = [...base].reduce((n, c, i) => n + Number(c) * (i % 2 ? 3 : 1), 0);
  return base + (10 - sum % 10) % 10;
}
