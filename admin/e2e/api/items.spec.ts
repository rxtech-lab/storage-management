import { test, expect } from "@playwright/test";

test.describe.serial("Items API", () => {
  let createdItemId: number;

  test("POST /api/v1/items - should create a new item", async ({ request }) => {
    const response = await request.post("/api/v1/items", {
      data: {
        title: "Test Item from API",
        description: "Created via API test",
        visibility: "private",
      },
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body).toHaveProperty("id");
    expect(body.title).toBe("Test Item from API");
    expect(body.description).toBe("Created via API test");
    expect(body.visibility).toBe("private");
    // Should include images (empty for items without images)
    expect(body).toHaveProperty("images");
    expect(body.images).toBeInstanceOf(Array);

    createdItemId = body.id;
  });

  test("GET /api/v1/items - should list all items", async ({ request }) => {
    const response = await request.get("/api/v1/items");

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body).toBeInstanceOf(Array);
    expect(body.length).toBeGreaterThan(0);
  });

  test("GET /api/v1/items?search=Test - should filter items by search", async ({
    request,
  }) => {
    const response = await request.get("/api/v1/items?search=Test");

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body).toBeInstanceOf(Array);
    expect(
      body.every(
        (item: any) =>
          item.title.includes("Test") || item.description?.includes("Test"),
      ),
    ).toBeTruthy();
  });

  test("GET /api/v1/items/{id} - should get item by ID", async ({
    request,
  }) => {
    const response = await request.get(`/api/v1/items/${createdItemId}`);

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.id).toBe(createdItemId);
    expect(body.title).toBe("Test Item from API");
    expect(body.previewUrl).toContain(`/preview/item/${createdItemId}`);
  });

  test("GET /api/v1/items/999999 - should return 404 for non-existent item", async ({
    request,
  }) => {
    const response = await request.get("/api/v1/items/999999");

    expect(response.status()).toBe(404);
    const body = await response.json();
    expect(body).toHaveProperty("error");
  });

  test("PUT /api/v1/items/{id} - should update item", async ({ request }) => {
    const response = await request.put(`/api/v1/items/${createdItemId}`, {
      data: {
        title: "Updated Test Item",
        description: "Updated via API test",
        visibility: "public",
      },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.title).toBe("Updated Test Item");
    expect(body.visibility).toBe("public");
    expect(body.previewUrl).toContain(`/preview/item/${createdItemId}`);
  });

  test("GET /api/v1/items/{id} - should include children in response", async ({
    request,
  }) => {
    // Create a child item for the parent
    const childResponse = await request.post("/api/v1/items", {
      data: {
        title: "Child Item",
        description: "Child of test item",
        parentId: createdItemId,
        visibility: "public",
      },
    });
    expect(childResponse.status()).toBe(201);
    const childItem = await childResponse.json();

    // Fetch the parent item and verify children are included
    const response = await request.get(`/api/v1/items/${createdItemId}`);
    expect(response.status()).toBe(200);
    const body = await response.json();

    expect(body).toHaveProperty("children");
    expect(body.children).toBeInstanceOf(Array);
    expect(body.children.length).toBe(1);
    expect(body.children[0].id).toBe(childItem.id);
    expect(body.children[0].title).toBe("Child Item");
    expect(body.children[0]).toHaveProperty("previewUrl");

    // Clean up child item
    await request.delete(`/api/v1/items/${childItem.id}`);
  });

  test("DELETE /api/v1/items/{id} - should delete item", async ({
    request,
  }) => {
    const response = await request.delete(`/api/v1/items/${createdItemId}`);

    expect(response.status()).toBe(200);

    // Verify item is deleted
    const getResponse = await request.get(`/api/v1/items/${createdItemId}`);
    expect(getResponse.status()).toBe(404);
  });

  test("POST /api/v1/items - should validate required fields", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/items", {
      data: {
        description: "Missing title",
      },
    });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body).toHaveProperty("error");
  });
});
