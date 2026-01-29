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
    expect(body.data).toHaveProperty("id");
    expect(body.data.title).toBe("Test Item from API");
    expect(body.data.description).toBe("Created via API test");
    expect(body.data.visibility).toBe("private");

    createdItemId = body.data.id;
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
    expect(body.data.id).toBe(createdItemId);
    expect(body.data.title).toBe("Test Item from API");
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
    expect(body.data.title).toBe("Updated Test Item");
    expect(body.data.visibility).toBe("public");
  });

  test("GET /api/v1/items/{id}/children - should get item children", async ({
    request,
  }) => {
    const response = await request.get(
      `/api/v1/items/${createdItemId}/children`,
    );

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.data).toBeInstanceOf(Array);
  });

  test("GET /api/v1/items/{id}/qr - should get QR code for item", async ({
    request,
  }) => {
    const response = await request.get(`/api/v1/items/${createdItemId}/qr`);

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.data).toHaveProperty("item_id", createdItemId);
    expect(body.data).toHaveProperty("preview_url");
    expect(body.data).toHaveProperty("qr_code_data_url");
    expect(body.data.qr_code_data_url).toMatch(/^data:image\/png;base64,/);
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
