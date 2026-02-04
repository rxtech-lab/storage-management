import { test, expect } from "@playwright/test";
import {
  ItemResponseSchema,
  ItemDetailResponseSchema,
  PaginatedItemsResponse,
} from "@/lib/schemas/items";

test.describe.serial("Items API", () => {
  let createdItemId: number;

  test("POST /api/v1/items - should create a new item", async ({ request }) => {
    const response = await request.post("/api/v1/items", {
      data: {
        title: "Test Item from API",
        description: "Created via API test",
        visibility: "privateAccess",
      },
    });

    expect(response.status()).toBe(201);
    const body = await response.json();

    // Validate response matches OpenAPI schema
    const validated = ItemResponseSchema.parse(body);

    expect(validated.id).toBeDefined();
    expect(validated.title).toBe("Test Item from API");
    expect(validated.description).toBe("Created via API test");
    expect(validated.visibility).toBe("privateAccess");
    expect(validated.images).toBeInstanceOf(Array);

    createdItemId = validated.id;
  });

  test("GET /api/v1/items - should list all items", async ({ request }) => {
    const response = await request.get("/api/v1/items");

    expect(response.status()).toBe(200);
    const body = await response.json();

    // Validate response matches OpenAPI schema
    const validated = PaginatedItemsResponse.parse(body);

    expect(validated.data).toBeInstanceOf(Array);
    expect(validated.data.length).toBeGreaterThan(0);
    expect(validated.pagination).toBeDefined();
  });

  test("GET /api/v1/items?search=Test - should filter items by search", async ({
    request,
  }) => {
    const response = await request.get("/api/v1/items?search=Test");

    expect(response.status()).toBe(200);
    const body = await response.json();

    // Validate response matches OpenAPI schema
    const validated = PaginatedItemsResponse.parse(body);

    expect(validated.data).toBeInstanceOf(Array);
    expect(
      validated.data.every(
        (item) =>
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

    // Validate response matches OpenAPI schema (detail includes children, contents, positions)
    const validated = ItemDetailResponseSchema.parse(body);

    expect(validated.id).toBe(createdItemId);
    expect(validated.title).toBe("Test Item from API");
    expect(validated.previewUrl).toContain(`/preview/item/${createdItemId}`);
    expect(validated.children).toBeInstanceOf(Array);
    expect(validated.contents).toBeInstanceOf(Array);
    expect(validated.positions).toBeInstanceOf(Array);
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
        visibility: "publicAccess",
      },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();

    // Validate response matches OpenAPI schema
    const validated = ItemResponseSchema.parse(body);

    expect(validated.title).toBe("Updated Test Item");
    expect(validated.visibility).toBe("publicAccess");
    expect(validated.previewUrl).toContain(`/preview/item/${createdItemId}`);
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
        visibility: "publicAccess",
      },
    });
    expect(childResponse.status()).toBe(201);
    const childItem = ItemResponseSchema.parse(await childResponse.json());

    // Fetch the parent item and verify children are included
    const response = await request.get(`/api/v1/items/${createdItemId}`);
    expect(response.status()).toBe(200);
    const body = await response.json();

    // Validate response matches OpenAPI schema
    const validated = ItemDetailResponseSchema.parse(body);

    expect(validated.children).toBeInstanceOf(Array);
    expect(validated.children.length).toBe(1);
    expect(validated.children[0].id).toBe(childItem.id);
    expect(validated.children[0].title).toBe("Child Item");
    expect(validated.children[0].previewUrl).toBeDefined();

    // Clean up child item
    await request.delete(`/api/v1/items/${childItem.id}`);
  });

  test("DELETE /api/v1/items/{id} - should delete item", async ({
    request,
  }) => {
    const response = await request.delete(`/api/v1/items/${createdItemId}`);

    expect(response.status()).toBe(204);

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

  test("POST /api/v1/items - should reject full URLs in images array", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/items", {
      data: {
        title: "Test Item with Invalid Images",
        visibility: "privateAccess",
        images: ["https://example.com/image.jpg"],
      },
    });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body).toHaveProperty("error");
    expect(body.error).toContain("file:{id}");
  });

  test("POST /api/v1/items - should reject mixed format in images array", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/items", {
      data: {
        title: "Test Item with Mixed Images",
        visibility: "privateAccess",
        images: ["file:1", "https://example.com/image.jpg"],
      },
    });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body).toHaveProperty("error");
  });

  test("GET /api/v1/items - images should be objects with id and url", async ({
    request,
  }) => {
    const response = await request.get("/api/v1/items");

    expect(response.status()).toBe(200);
    const body = await response.json();

    // Validate response matches OpenAPI schema (this validates images are {id, url} objects)
    const validated = PaginatedItemsResponse.parse(body);

    expect(validated.data).toBeInstanceOf(Array);

    // Additional check: images should be objects with id and url per schema
    for (const item of validated.data) {
      expect(item.images).toBeInstanceOf(Array);
      for (const image of item.images) {
        expect(typeof image).toBe("object");
        expect(typeof image.id).toBe("number");
        expect(typeof image.url).toBe("string");
        // URL should be valid
        expect(() => new URL(image.url)).not.toThrow();
      }
    }
  });
});
