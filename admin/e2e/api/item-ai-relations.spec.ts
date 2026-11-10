import { test, expect } from "@playwright/test";

test("AI suggestions reuse only the current user's records and validate tag ownership", async ({ request }) => {
  const suffix = crypto.randomUUID();
  const alice = { "X-Test-User-Id": `alice-${suffix}` };
  const bob = { "X-Test-User-Id": `bob-${suffix}` };
  const data = { category: "Cameras", author: "Maker", tags: ["portable", "portable"] };
  const first = await request.post("/api/v1/items/ai/relations", { headers: alice, data });
  expect(first.status()).toBe(200);
  const a = await first.json();
  const second = await request.post("/api/v1/items/ai/relations", { headers: alice, data });
  expect(await second.json()).toEqual(a); expect(a.tagIds).toHaveLength(1);
  const third = await request.post("/api/v1/items/ai/relations", { headers: bob, data });
  const b = await third.json();
  expect(b.categoryId).not.toBe(a.categoryId); expect(b.authorId).not.toBe(a.authorId); expect(b.tagIds).not.toEqual(a.tagIds);
  const forbidden = await request.post("/api/v1/items", { headers: bob, data: { title: "Forbidden tags", visibility: "privateAccess", tagIds: a.tagIds } });
  expect(forbidden.status()).toBe(400);
  const created = await request.post("/api/v1/items", { headers: alice, data: { title: "Tagged camera", visibility: "privateAccess", categoryId: a.categoryId, authorId: a.authorId, tagIds: a.tagIds, originalQrCode: "camera-qr" } });
  expect(created.status()).toBe(201);
  const item = await created.json();
  const detail = await request.get(`/api/v1/items/${item.id}`, { headers: alice });
  const saved = await detail.json();
  expect(saved.tags.map((tag: { id: string }) => tag.id)).toEqual(a.tagIds); expect(saved.originalQrCode).toBe("camera-qr");
  const update = await request.put(`/api/v1/items/${item.id}`, { headers: alice, data: { tagIds: a.tagIds } });
  expect(update.ok()).toBe(true);
  const detailAgain = await request.get(`/api/v1/items/${item.id}`, { headers: alice });
  expect((await detailAgain.json()).tags).toHaveLength(1);
});

test("AI endpoint rejects external URLs and another user's image references", async ({ request }) => {
  const invalid = await request.post("/api/v1/items/ai", { data: { prompt: "camera", images: ["http://localhost/private"] } });
  expect(invalid.status()).toBe(400);
  const forbidden = await request.post("/api/v1/items/ai", { data: { images: ["file:missing"] } });
  expect(forbidden.status()).toBe(403);
});
