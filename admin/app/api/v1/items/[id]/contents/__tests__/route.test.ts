// @vitest-environment node
import { beforeEach, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

const mocks = vi.hoisted(() => ({
  session: vi.fn(), item: vi.fn(), existing: vi.fn(), create: vi.fn(),
  remove: vi.fn(), resolve: vi.fn(),
}));
vi.mock("@/lib/auth-helper", () => ({ getSession: mocks.session }));
vi.mock("@/lib/actions/item-actions", () => ({ getItem: mocks.item }));
vi.mock("@/lib/actions/content-actions", () => ({
  getItemContents: mocks.existing,
  getItemContentsPaginated: vi.fn(),
  createContentAction: mocks.create,
  deleteContentAction: mocks.remove,
  resolveContentFileRefs: mocks.resolve,
}));
import { POST } from "../route";

const hash = "ab".repeat(32);
const data = { title: "manual.pdf", mime_type: "application/pdf", size: 42, file_path: "manual.pdf" };
function create(metadata: object, overwrite = false) {
  return POST(new NextRequest("http://localhost/api/v1/items/item/contents", {
    method: "POST", body: JSON.stringify({ type: "file", data: metadata, overwrite }),
  }), { params: Promise.resolve({ id: "item" }) });
}
beforeEach(() => {
  vi.resetAllMocks();
  mocks.session.mockResolvedValue({ user: { id: "owner" } });
  mocks.item.mockResolvedValue({ id: "item", userId: "owner" });
  mocks.existing.mockResolvedValue([]);
  mocks.create.mockImplementation(async (input) => ({ success: true, data: { id: "new", ...input } }));
  mocks.resolve.mockImplementation(async (input) => input);
});

it("keeps SHA-256 optional for legacy clients", async () => {
  expect((await create(data)).status).toBe(201);
  expect(mocks.existing).not.toHaveBeenCalled();
});
it("persists and returns a supplied SHA-256", async () => {
  const response = await create({ ...data, sha256: hash });
  expect(response.status).toBe(201);
  expect((await response.json()).data.sha256).toBe(hash);
  expect(mocks.existing).toHaveBeenCalledWith("item");
});
it("rejects an existing hash regardless of title and letter case", async () => {
  mocks.existing.mockResolvedValue([{ id: "old", data: { ...data, title: "other.pdf", sha256: hash.toUpperCase() } }]);
  const response = await create({ ...data, sha256: hash });
  expect(response.status).toBe(400);
  expect((await response.json()).error).toContain("SHA-256");
  expect(mocks.create).not.toHaveBeenCalled();
});
it("rejects duplicate hashes before overwrite deletes existing content", async () => {
  mocks.existing.mockResolvedValue([{ id: "old", data: { ...data, sha256: hash } }]);
  expect((await create({ ...data, sha256: hash }, true)).status).toBe(400);
  expect(mocks.remove).not.toHaveBeenCalled();
  expect(mocks.create).not.toHaveBeenCalled();
});
it.each(["", "z".repeat(64), "a".repeat(63), 123, null])("rejects invalid SHA-256: %s", async (sha256) => {
  expect((await create({ ...data, sha256 })).status).toBe(400);
  expect(mocks.create).not.toHaveBeenCalled();
});
it("checks ownership before looking for duplicate hashes", async () => {
  mocks.item.mockResolvedValue({ id: "item", userId: "other" });
  expect((await create({ ...data, sha256: hash })).status).toBe(404);
  expect(mocks.existing).not.toHaveBeenCalled();
});
