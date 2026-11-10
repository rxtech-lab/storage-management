import { beforeEach, describe, expect, it, vi } from "vitest";
const mocks = vi.hoisted(() => ({ session: vi.fn(), files: vi.fn(), sign: vi.fn(), generate: vi.fn(), model: vi.fn(), search: vi.fn() }));
vi.mock("@/lib/auth-helper", () => ({ getSession: mocks.session }));
vi.mock("@/lib/actions/file-actions", () => ({ getFiles: mocks.files }));
vi.mock("@/lib/actions/s3-upload-actions", () => ({ signFileUrlsAction: mocks.sign }));
vi.mock("ai", () => ({ generateText: mocks.generate, gateway: Object.assign(mocks.model, { tools: { perplexitySearch: mocks.search } }), Output: { object: vi.fn() } }));
import { POST } from "../route";
const draft = { title: "Camera", description: "A camera", originalQrCode: null, category: "Cameras", author: null, tags: ["photography"] };
const request = (body: unknown) => new Request("http://localhost/api/v1/items/ai", { method: "POST", body: JSON.stringify(body) });
describe("item AI boundary", () => {
  beforeEach(() => { vi.resetAllMocks(); mocks.session.mockResolvedValue({ user: { id: "owner" } }); mocks.files.mockResolvedValue([]); });
  it("requires authentication before calling AI", async () => {
    mocks.session.mockResolvedValue(null);
    expect((await POST(request({ prompt: "camera" }))).status).toBe(401);
    expect(mocks.generate).not.toHaveBeenCalled();
  });
  it("rejects empty input and arbitrary image URLs", async () => {
    expect((await POST(request({}))).status).toBe(400);
    expect((await POST(request({ images: ["http://internal/image"] }))).status).toBe(400);
    expect(mocks.generate).not.toHaveBeenCalled();
  });
  it("rejects another user's image before signing or calling the model", async () => {
    mocks.files.mockResolvedValue([{ id: "private", userId: "other", contentType: "image/png" }]);
    expect((await POST(request({ images: ["file:private"] }))).status).toBe(403);
    expect(mocks.sign).not.toHaveBeenCalled(); expect(mocks.generate).not.toHaveBeenCalled();
  });
  it("rejects malformed JSON before calling the model", async () => {
    const response = await POST(new Request("http://localhost/api/v1/items/ai", { method: "POST", body: "{" }));
    expect(response.status).toBe(400);
    expect(mocks.generate).not.toHaveBeenCalled();
  });
  it("rejects oversized or unsupported owned image formats", async () => {
    mocks.files.mockResolvedValue([{ id: "photo", userId: "owner", contentType: "image/png", size: 11 * 1024 * 1024 }]);
    expect((await POST(request({ images: ["file:photo"] }))).status).toBe(400);
    mocks.files.mockResolvedValue([{ id: "photo", userId: "owner", contentType: "image/heic", size: 100 }]);
    expect((await POST(request({ images: ["file:photo"] }))).status).toBe(400);
    expect(mocks.sign).not.toHaveBeenCalled();
    expect(mocks.generate).not.toHaveBeenCalled();
  });
  it("uses signed owned images, searches online, and preserves the supplied QR", async () => {
    mocks.files.mockResolvedValue([{ id: "photo", userId: "owner", contentType: "image/png" }]);
    mocks.sign.mockResolvedValue({ success: true, data: [{ signedUrl: "https://s3.example.com/photo" }] });
    mocks.generate.mockResolvedValueOnce({ text: "Canon camera" }).mockResolvedValueOnce({ toolResults: [{ output: { results: [{ title: "Canon", url: "https://canon.com", snippet: "Official details" }] } }] }).mockResolvedValueOnce({ output: draft });
    const response = await POST(request({ images: ["file:photo"], originalQrCode: "original-value" }));
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ draft: { ...draft, originalQrCode: "original-value" }, sources: [{ title: "Canon", url: "https://canon.com" }] });
    expect(mocks.model).toHaveBeenCalledWith("openai/gpt-4.1-mini");
    expect(mocks.generate.mock.calls[0][0].messages[0].content[1].image.href).toBe("https://s3.example.com/photo");
    expect(mocks.generate.mock.calls[1][0].toolChoice).toBe("required");
  });
  it("can draft without web search", async () => {
    mocks.generate.mockResolvedValueOnce({ text: "Camera" }).mockResolvedValueOnce({ output: draft });
    const response = await POST(request({ prompt: "camera", webSearch: false }));
    expect(response.status).toBe(200); expect((await response.json()).sources).toEqual([]);
    expect(mocks.search).not.toHaveBeenCalled();
  });
  it("reports search failure instead of claiming online research", async () => {
    mocks.generate.mockResolvedValueOnce({ text: "Camera" }).mockResolvedValueOnce({ toolResults: [{ output: { error: "timeout" } }] });
    expect((await POST(request({ prompt: "camera" }))).status).toBe(502);
    expect(mocks.generate).toHaveBeenCalledTimes(2);
  });
});
