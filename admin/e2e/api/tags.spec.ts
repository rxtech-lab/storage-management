import { test, expect } from "@playwright/test";
import crypto from "crypto";

const TEST_USER_ID = `tags-api-test-user-${crypto.randomUUID()}`;

test.describe.serial("Tags API", () => {
  let createdTagId: string;
  let createdItemId: string;

  test("POST /api/v1/tags - should create a new tag", async ({ request }) => {
    const response = await request.post("/api/v1/tags", {
      headers: { "X-Test-User-Id": TEST_USER_ID },
      data: {
        title: "Test Tag",
        color: "#ff5733",
      },
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body).toHaveProperty("id");
    expect(body.title).toBe("Test Tag");
    expect(body.color).toBe("#ff5733");

    createdTagId = body.id;
  });

  test("GET /api/v1/tags - should list all tags", async ({ request }) => {
    const response = await request.get("/api/v1/tags", {
      headers: { "X-Test-User-Id": TEST_USER_ID },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body).toBeInstanceOf(Array);
    expect(body.length).toBeGreaterThan(0);
  });

  test("GET /api/v1/tags/{id} - should get tag by ID with items and totalItems", async ({
    request,
  }) => {
    const response = await request.get(`/api/v1/tags/${createdTagId}`, {
      headers: { "X-Test-User-Id": TEST_USER_ID },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.id).toBe(createdTagId);
    expect(body.title).toBe("Test Tag");
    expect(body.color).toBe("#ff5733");
    expect(body).toHaveProperty("items");
    expect(body.items).toBeInstanceOf(Array);
    expect(body).toHaveProperty("totalItems");
    expect(typeof body.totalItems).toBe("number");
  });

  test("GET /api/v1/tags/{id} - should return items associated with the tag", async ({
    request,
  }) => {
    // Create an item first
    const itemResponse = await request.post("/api/v1/items", {
      headers: { "X-Test-User-Id": TEST_USER_ID },
      data: {
        title: "Item With Tag",
        visibility: "publicAccess",
      },
    });
    expect(itemResponse.status()).toBe(201);
    const item = await itemResponse.json();
    createdItemId = item.id;

    // Add the tag to the item
    const addTagResponse = await request.post(
      `/api/v1/items/${createdItemId}/tags`,
      {
        headers: { "X-Test-User-Id": TEST_USER_ID },
        data: { tagId: createdTagId },
      },
    );
    expect(addTagResponse.status()).toBe(201);

    // Get tag detail and verify the item is included
    const tagResponse = await request.get(`/api/v1/tags/${createdTagId}`, {
      headers: { "X-Test-User-Id": TEST_USER_ID },
    });
    expect(tagResponse.status()).toBe(200);
    const tagBody = await tagResponse.json();

    expect(tagBody.items).toBeInstanceOf(Array);
    expect(tagBody.totalItems).toBeGreaterThanOrEqual(1);

    const itemInTag = tagBody.items.find(
      (i: { id: string }) => i.id === createdItemId,
    );
    expect(itemInTag).toBeDefined();
    expect(itemInTag.title).toBe("Item With Tag");
  });

  test("GET /api/v1/tags/{id} - should limit items to 10", async ({
    request,
  }) => {
    const tagResponse = await request.post("/api/v1/tags", {
      headers: { "X-Test-User-Id": TEST_USER_ID },
      data: {
        title: "Pagination Test Tag",
        color: "#0000ff",
      },
    });
    expect(tagResponse.status()).toBe(201);
    const tag = await tagResponse.json();
    const paginationTagId = tag.id;

    // Create 12 items and assign the tag
    for (let i = 0; i < 12; i++) {
      const itemRes = await request.post("/api/v1/items", {
        headers: { "X-Test-User-Id": TEST_USER_ID },
        data: { title: `Pagination Item ${i}`, visibility: "publicAccess" },
      });
      expect(itemRes.status()).toBe(201);
      const createdItem = await itemRes.json();

      const addTagRes = await request.post(
        `/api/v1/items/${createdItem.id}/tags`,
        {
          headers: { "X-Test-User-Id": TEST_USER_ID },
          data: { tagId: paginationTagId },
        },
      );
      expect(addTagRes.status()).toBe(201);
    }

    // Fetch tag detail and verify items are limited to 10
    const detailResponse = await request.get(
      `/api/v1/tags/${paginationTagId}`,
      {
        headers: { "X-Test-User-Id": TEST_USER_ID },
      },
    );
    expect(detailResponse.status()).toBe(200);
    const detailBody = await detailResponse.json();

    expect(detailBody.items.length).toBeLessThanOrEqual(10);
    expect(detailBody.totalItems).toBe(12);
  });

  test("PUT /api/v1/tags/{id} - should update tag", async ({ request }) => {
    const response = await request.put(`/api/v1/tags/${createdTagId}`, {
      headers: { "X-Test-User-Id": TEST_USER_ID },
      data: {
        title: "Updated Tag",
        color: "#00ff00",
      },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.title).toBe("Updated Tag");
    expect(body.color).toBe("#00ff00");
  });

  test("DELETE /api/v1/tags/{id} - should delete tag", async ({ request }) => {
    const response = await request.delete(`/api/v1/tags/${createdTagId}`, {
      headers: { "X-Test-User-Id": TEST_USER_ID },
    });

    expect(response.status()).toBe(200);

    // Verify tag is deleted
    const getResponse = await request.get(`/api/v1/tags/${createdTagId}`, {
      headers: { "X-Test-User-Id": TEST_USER_ID },
    });
    expect(getResponse.status()).toBe(404);
  });

  test("POST /api/v1/tags - should validate required fields", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/tags", {
      headers: { "X-Test-User-Id": TEST_USER_ID },
      data: {
        title: "Missing color",
      },
    });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body).toHaveProperty("error");
  });
});

test.describe.serial("Tags API - Multi-user Isolation", () => {
  const USER_1 = `tag-isolation-user-1-${crypto.randomUUID()}`;
  const USER_2 = `tag-isolation-user-2-${crypto.randomUUID()}`;
  let user1TagId: string;

  test("User 1 creates a tag", async ({ request }) => {
    const response = await request.post("/api/v1/tags", {
      headers: { "X-Test-User-Id": USER_1 },
      data: {
        title: "User1 Tag",
        color: "#ff0000",
      },
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body.title).toBe("User1 Tag");
    user1TagId = body.id;
  });

  test("User 2 cannot see User 1 tag in list", async ({ request }) => {
    const response = await request.get("/api/v1/tags", {
      headers: { "X-Test-User-Id": USER_2 },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body).toBeInstanceOf(Array);
    const user1Tags = body.filter(
      (t: { id: string }) => t.id === user1TagId,
    );
    expect(user1Tags.length).toBe(0);
  });

  test("User 2 gets 403 when accessing User 1 tag by ID", async ({
    request,
  }) => {
    const response = await request.get(`/api/v1/tags/${user1TagId}`, {
      headers: { "X-Test-User-Id": USER_2 },
    });

    expect(response.status()).toBe(403);
    const body = await response.json();
    expect(body.error).toBe("Permission denied");
  });

  test("User 2 gets 403 when updating User 1 tag", async ({ request }) => {
    const response = await request.put(`/api/v1/tags/${user1TagId}`, {
      headers: { "X-Test-User-Id": USER_2 },
      data: {
        title: "Hacked Tag",
      },
    });

    expect(response.status()).toBe(403);
    const body = await response.json();
    expect(body.error).toBe("Permission denied");
  });

  test("User 2 gets 403 when deleting User 1 tag", async ({ request }) => {
    const response = await request.delete(`/api/v1/tags/${user1TagId}`, {
      headers: { "X-Test-User-Id": USER_2 },
    });

    expect(response.status()).toBe(403);
    const body = await response.json();
    expect(body.error).toBe("Permission denied");
  });

  test("User 1 can still access their own tag", async ({ request }) => {
    const response = await request.get(`/api/v1/tags/${user1TagId}`, {
      headers: { "X-Test-User-Id": USER_1 },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.id).toBe(user1TagId);
    expect(body.title).toBe("User1 Tag");
    expect(body).toHaveProperty("items");
    expect(body).toHaveProperty("totalItems");
  });

  test("User 1 can delete their own tag", async ({ request }) => {
    const response = await request.delete(`/api/v1/tags/${user1TagId}`, {
      headers: { "X-Test-User-Id": USER_1 },
    });

    expect(response.status()).toBe(200);

    // Verify tag is deleted
    const getResponse = await request.get(`/api/v1/tags/${user1TagId}`, {
      headers: { "X-Test-User-Id": USER_1 },
    });
    expect(getResponse.status()).toBe(404);
  });
});
