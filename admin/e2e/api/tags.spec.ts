import { test, expect } from "@playwright/test";

test.describe.serial("Tags API", () => {
  const USER_ID = `tags-api-test-user-${crypto.randomUUID()}`;
  const headers = { "X-Test-User-Id": USER_ID };

  let createdTagId: string;

  test("POST /api/v1/tags - should create a new tag", async ({ request }) => {
    const response = await request.post("/api/v1/tags", {
      headers,
      data: {
        title: "Test Tag",
        color: "#FF5733",
      },
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body).toHaveProperty("id");
    expect(body.title).toBe("Test Tag");
    expect(body.color).toBe("#FF5733");

    createdTagId = body.id;
  });

  test("GET /api/v1/tags - should list all tags", async ({ request }) => {
    const response = await request.get("/api/v1/tags", { headers });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body).toBeInstanceOf(Array);
    expect(body.length).toBeGreaterThan(0);
    expect(body[0].title).toBe("Test Tag");
  });

  test("GET /api/v1/tags/{id} - should get tag by ID with items and totalItems", async ({
    request,
  }) => {
    const response = await request.get(`/api/v1/tags/${createdTagId}`, {
      headers,
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.id).toBe(createdTagId);
    expect(body.title).toBe("Test Tag");
    expect(body.color).toBe("#FF5733");
    // Should include items and totalItems fields
    expect(body).toHaveProperty("items");
    expect(body).toHaveProperty("totalItems");
    expect(Array.isArray(body.items)).toBe(true);
    expect(body.items).toHaveLength(0);
    expect(body.totalItems).toBe(0);
  });

  test("PUT /api/v1/tags/{id} - should update tag", async ({ request }) => {
    const response = await request.put(`/api/v1/tags/${createdTagId}`, {
      headers,
      data: {
        title: "Updated Tag",
        color: "#00FF00",
      },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.title).toBe("Updated Tag");
    expect(body.color).toBe("#00FF00");
  });

  test("DELETE /api/v1/tags/{id} - should delete tag", async ({ request }) => {
    const response = await request.delete(`/api/v1/tags/${createdTagId}`, {
      headers,
    });

    expect(response.status()).toBe(200);

    // Verify tag is deleted
    const getResponse = await request.get(`/api/v1/tags/${createdTagId}`, {
      headers,
    });
    expect(getResponse.status()).toBe(404);
  });

  test("POST /api/v1/tags - should validate required fields", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/tags", {
      headers,
      data: {
        color: "#FF0000",
      },
    });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body).toHaveProperty("error");
  });
});

test.describe.serial("Tags API - Detail with Items", () => {
  const USER_ID = `tags-detail-test-user-${crypto.randomUUID()}`;
  const headers = { "X-Test-User-Id": USER_ID };

  let tagId: string;
  const itemIds: string[] = [];

  test("setup - create tag and items", async ({ request }) => {
    // Create a tag
    const tagRes = await request.post("/api/v1/tags", {
      headers,
      data: { title: "Detail Test Tag", color: "#3366FF" },
    });
    expect(tagRes.status()).toBe(201);
    tagId = (await tagRes.json()).id;

    // Create 3 items and assign the tag to them
    for (let i = 1; i <= 3; i++) {
      const itemRes = await request.post("/api/v1/items", {
        headers,
        data: {
          title: `Tag Detail Item ${i}`,
          visibility: "privateAccess",
        },
      });
      expect(itemRes.status()).toBe(201);
      const itemId = (await itemRes.json()).id;
      itemIds.push(itemId);

      // Assign tag to item
      const tagAssignRes = await request.post(
        `/api/v1/items/${itemId}/tags`,
        {
          headers,
          data: { tagId },
        }
      );
      expect(tagAssignRes.status()).toBe(201);
    }
  });

  test("GET /api/v1/tags/{id} - should return tag with related items", async ({
    request,
  }) => {
    const response = await request.get(`/api/v1/tags/${tagId}`, { headers });

    expect(response.status()).toBe(200);
    const body = await response.json();

    // Tag fields
    expect(body.id).toBe(tagId);
    expect(body.title).toBe("Detail Test Tag");
    expect(body.color).toBe("#3366FF");

    // Items should be included
    expect(body.items).toHaveLength(3);
    expect(body.totalItems).toBe(3);

    // Verify items contain the correct items
    const returnedIds = body.items.map((item: { id: string }) => item.id);
    for (const id of itemIds) {
      expect(returnedIds).toContain(id);
    }

    // Each item should have standard fields
    for (const item of body.items) {
      expect(item).toHaveProperty("id");
      expect(item).toHaveProperty("title");
      expect(item).toHaveProperty("userId");
      expect(item).toHaveProperty("previewUrl");
    }
  });

  test("GET /api/v1/tags/{id} - should limit items to 10", async ({
    request,
  }) => {
    // Create 9 more items (total 12) to test the limit
    for (let i = 4; i <= 12; i++) {
      const itemRes = await request.post("/api/v1/items", {
        headers,
        data: {
          title: `Tag Detail Item ${i}`,
          visibility: "privateAccess",
        },
      });
      expect(itemRes.status()).toBe(201);
      const itemId = (await itemRes.json()).id;
      itemIds.push(itemId);

      await request.post(`/api/v1/items/${itemId}/tags`, {
        headers,
        data: { tagId },
      });
    }

    const response = await request.get(`/api/v1/tags/${tagId}`, { headers });

    expect(response.status()).toBe(200);
    const body = await response.json();

    // Should only return 10 items even though 12 are tagged
    expect(body.items).toHaveLength(10);
    expect(body.totalItems).toBe(12);
  });

  test("GET /api/v1/tags/{id} - should return 404 for non-existent tag", async ({
    request,
  }) => {
    const response = await request.get("/api/v1/tags/non-existent-id", {
      headers,
    });
    expect(response.status()).toBe(404);
  });

  test("cleanup - delete items and tag", async ({ request }) => {
    for (const id of itemIds) {
      await request.delete(`/api/v1/items/${id}`, { headers });
    }
    await request.delete(`/api/v1/tags/${tagId}`, { headers });
  });
});
