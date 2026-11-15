// @vitest-environment node
import { beforeEach, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

const mocks = vi.hoisted(() => ({
  session: vi.fn(), item: vi.fn(), existing: vi.fn(), create: vi.fn(),
  remove: vi.fn(), file: vi.fn(), sign: vi.fn(),
}));
vi.mock("@/lib/auth-helper", () => ({ getSession: mocks.session }));
vi.mock("@/lib/actions/item-actions", () => ({ getItem: mocks.item }));
vi.mock("@/lib/actions/content-actions", () => ({
  getItemContents: mocks.existing, createContentAction: mocks.create, deleteContentAction: mocks.remove,
}));
vi.mock("@/lib/actions/file-actions", () => ({ createFileRecordAction: mocks.file }));
vi.mock("@/lib/s3", () => ({ s3Client: {}, S3_BUCKET: "bucket" }));
vi.mock("@aws-sdk/s3-request-presigner", () => ({ getSignedUrl: mocks.sign }));
import { POST } from "../route";

const hash = "ab".repeat(32);
const metadata = { filename: "photo.jpg", title: "photo", type: "image", mime_type: "image/jpeg", size: 42, file_path: "photo.jpg", sha256: hash };
function upload(items: object[], overwrite = false) {
  return POST(new NextRequest("http://localhost/api/v1/upload/content-preview", {
    method: "POST", body: JSON.stringify({ item_id: "item", items, overwrite }),
  }));
}
beforeEach(() => {
  vi.resetAllMocks();
  mocks.session.mockResolvedValue({ user: { id: "owner" } });
  mocks.item.mockResolvedValue({ id: "item", userId: "owner" });
  mocks.existing.mockResolvedValue([]);
  mocks.file.mockResolvedValue({ success: true, data: { id: "preview" } });
  mocks.sign.mockResolvedValue("https://s3.example.com/preview");
  mocks.create.mockResolvedValue({ success: true });
});
it("rejects existing hashes before overwrite or preview allocation", async () => {
  mocks.existing.mockResolvedValue([{ id: "old", data: { title: "photo", sha256: hash.toUpperCase() } }]);
  expect((await upload([metadata], true)).status).toBe(400);
  expect(mocks.remove).not.toHaveBeenCalled();
  expect(mocks.file).not.toHaveBeenCalled();
  expect(mocks.create).not.toHaveBeenCalled();
});
it("rejects matching hashes within a batch before creating any content", async () => {
  expect((await upload([metadata, { ...metadata, filename: "copy.jpg", title: "copy", sha256: hash.toUpperCase() }])).status).toBe(400);
  expect(mocks.file).not.toHaveBeenCalled();
});
it("preserves SHA-256 on newly created image and video content", async () => {
  expect((await upload([metadata])).status).toBe(201);
  expect(mocks.create).toHaveBeenLastCalledWith(expect.objectContaining({ data: expect.objectContaining({ sha256: hash }) }));
  expect((await upload([{ ...metadata, type: "video", video_length: 5 }])).status).toBe(201);
  expect(mocks.create).toHaveBeenLastCalledWith(expect.objectContaining({ data: expect.objectContaining({ sha256: hash, video_length: 5 }) }));
});
it("rejects invalid hashes without creating previews", async () => {
  expect((await upload([{ ...metadata, sha256: "invalid" }])).status).toBe(400);
  expect(mocks.file).not.toHaveBeenCalled();
});
