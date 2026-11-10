// @vitest-environment node
import { beforeEach, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
const mocks = vi.hoisted(() => ({ session: vi.fn(), inventory: vi.fn(), lookup: vi.fn() }));
vi.mock("@/lib/auth-helper", () => ({ getSession: mocks.session }));
vi.mock("@/app/api/v1/qrcode/scan/route", () => ({ POST: mocks.inventory }));
vi.mock("@/lib/barcode-lookup", () => ({ lookupBarcode: mocks.lookup, BarcodeProviderError: class extends Error {} }));
import { POST } from "../route";
function request(body: unknown) { return new NextRequest("http://localhost/api/v1/items/lookup", { method: "POST", body: JSON.stringify(body) }); }
beforeEach(() => { vi.resetAllMocks(); mocks.session.mockResolvedValue({ user: { id: "owner" } }); mocks.inventory.mockResolvedValue(Response.json({ error: "Invalid QR code" }, { status: 400 })); mocks.lookup.mockResolvedValue(null); });
it("requires authentication before inventory and external lookup", async () => {
  mocks.session.mockResolvedValue(null);
  expect((await POST(request({ barcode: "9780140328721" }))).status).toBe(401);
  expect(mocks.inventory).not.toHaveBeenCalled(); expect(mocks.lookup).not.toHaveBeenCalled();
});
it("returns existing inventory without calling providers", async () => {
  mocks.inventory.mockResolvedValue(Response.json({ type: "item", url: "https://storage.rxlab.app/api/v1/items/one" }));
  const response = await POST(request({ barcode: "9780140328721" }));
  expect((await response.json()).itemUrl).toContain("/one"); expect(mocks.lookup).not.toHaveBeenCalled();
});
it("preserves inventory permission failures", async () => {
  mocks.inventory.mockResolvedValue(Response.json({ error: "Permission denied" }, { status: 403 }));
  expect((await POST(request({ barcode: "9780140328721" }))).status).toBe(403); expect(mocks.lookup).not.toHaveBeenCalled();
});
it("returns an explicit no-match result", async () => {
  const response = await POST(request({ barcode: "9780140328721", inventory: false }));
  expect(await response.json()).toEqual({ barcode: "9780140328721", itemUrl: null, result: null });
  expect(mocks.inventory).not.toHaveBeenCalled();
});
it("validates request size", async () => {
  expect((await POST(request({ barcode: "x".repeat(2001) }))).status).toBe(400);
  expect(mocks.lookup).not.toHaveBeenCalled();
});
it("returns a retryable upstream error", async () => {
  mocks.lookup.mockRejectedValue(new Error("offline"));
  expect((await POST(request({ barcode: "012345678905" }))).status).toBe(502);
});
