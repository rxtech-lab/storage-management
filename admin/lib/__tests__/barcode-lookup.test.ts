// @vitest-environment node
import { afterEach, describe, expect, it, vi } from "vitest";
import { lookupBarcode, normalizeBarcode } from "../barcode-lookup";

afterEach(() => vi.unstubAllGlobals());
describe("barcode identifiers", () => {
  it("validates ISBN-10, ISBN-13, UPC and EAN check digits", () => {
    for (const code of ["9780140328721", "0-14-032872-6", "080442957X", "012345678905", "4006381333931"]) expect(normalizeBarcode(code)).not.toBeNull();
    for (const code of ["9780140328722", "0140328727", "012345678906", "hello", "12345"]) expect(normalizeBarcode(code)).toBeNull();
  });
  it("extracts ISBN data without following scanned URLs", () => {
    expect(normalizeBarcode("https://example.com/book?isbn=9780140328721")).toEqual({ code: "9780140328721", book: true });
    expect(normalizeBarcode("ISBN: 978-0-14-032872-1")).toEqual({ code: "9780140328721", book: true });
    expect(normalizeBarcode("http://localhost/private")).toBeNull();
  });
});

describe("provider lookup", () => {
  it("maps exact Open Library metadata and preserves the scanned value", async () => {
    const fetcher = vi.fn().mockResolvedValue(Response.json({ "ISBN:9780140328721": { title: "Matilda", authors: [{ name: "Roald Dahl" }], publishers: [{ name: "Puffin" }], publish_date: "1988" } }));
    vi.stubGlobal("fetch", fetcher);
    const result = await lookupBarcode("ISBN: 9780140328721");
    expect(result?.draft).toMatchObject({ title: "Matilda", author: "Roald Dahl", originalQrCode: "ISBN: 9780140328721", category: "Books" });
    expect(fetcher).toHaveBeenCalledTimes(1);
  });
  it("falls back after provider failure and requires a matching ISBN", async () => {
    const fetcher = vi.fn().mockResolvedValueOnce(new Response("Down", { status: 503 })).mockResolvedValueOnce(Response.json({ items: [{ volumeInfo: { title: "Matilda", industryIdentifiers: [{ identifier: "0140328726" }] } }] }));
    vi.stubGlobal("fetch", fetcher);
    expect((await lookupBarcode("9780140328721"))?.draft.title).toBe("Matilda");
  });
  it("does not accept unrelated Google Books results", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValueOnce(Response.json({})).mockResolvedValueOnce(Response.json({ items: [{ volumeInfo: { title: "Unrelated", industryIdentifiers: [{ identifier: "9780306406157" }] } }] })).mockResolvedValueOnce(Response.json({ code: "OK", items: [] })));
    expect(await lookupBarcode("9780140328721")).toBeNull();
  });
  it("looks up a product only when its identifier matches", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(Response.json({ code: "OK", items: [{ title: "Product", upc: "012345678905", brand: "Brand" }] })));
    expect((await lookupBarcode("012345678905"))?.draft).toMatchObject({ title: "Product", author: null });
  });
  it("returns a retryable error for rate limits, invalid JSON and network failures", async () => {
    for (const response of [new Response("", { status: 429 }), new Response("<html>not JSON</html>")]) {
      vi.stubGlobal("fetch", vi.fn().mockResolvedValue(response));
      await expect(lookupBarcode("012345678905")).rejects.toThrow("Try again later");
    }
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("offline")));
    await expect(lookupBarcode("012345678905")).rejects.toThrow("Try again later");
  });
  it("does not call providers for an unsupported QR value", async () => {
    const fetcher = vi.fn(); vi.stubGlobal("fetch", fetcher);
    expect(await lookupBarcode("https://example.com/private")).toBeNull();
    expect(fetcher).not.toHaveBeenCalled();
  });
});

it("retrieves a regional book from the retail catalog when Google Books is rate limited", async () => {
  const fetcher = vi.fn()
    .mockResolvedValueOnce(Response.json({}))
    .mockResolvedValueOnce(new Response("quota exhausted", { status: 429 }))
    .mockResolvedValueOnce(Response.json({ code: "OK", items: [{ title: "Regional Book", ean: "9780140328721", description: "Publisher details" }] }));
  vi.stubGlobal("fetch", fetcher);
  const result = await lookupBarcode("0140328726");
  expect(result?.draft).toMatchObject({ title: "Regional Book", category: "Books", originalQrCode: "0140328726" });
  expect(fetcher.mock.calls[2][0]).toContain("upc=9780140328721");
});

it("reports provider quota exhaustion without calling it a missing book", async () => {
  vi.stubGlobal("fetch", vi.fn()
    .mockResolvedValueOnce(Response.json({}))
    .mockResolvedValueOnce(new Response("quota exhausted", { status: 429 }))
    .mockResolvedValueOnce(Response.json({ code: "OK", items: [] })));
  await expect(lookupBarcode("9780140328721")).rejects.toThrow("Google Books: lookup limit reached");
});

it("keeps an actual catalog miss distinct from provider failures", async () => {
  vi.stubGlobal("fetch", vi.fn()
    .mockResolvedValueOnce(Response.json({}))
    .mockResolvedValueOnce(Response.json({ totalItems: 0 }))
    .mockResolvedValueOnce(Response.json({ code: "OK", items: [] })));
  expect(await lookupBarcode("9780140328721")).toBeNull();
});
