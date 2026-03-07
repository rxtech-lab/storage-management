import { test, expect } from "@playwright/test";
import { ItemResponseSchema } from "@/lib/schemas/items";

/**
 * Tests that item titles are unique per user.
 * Creating or updating an item with a duplicate title should return 409 Conflict.
 */
test.describe.serial("Items Unique Title", () => {
  const USER_ID = `unique-title-test-user-${crypto.randomUUID()}`;
  const headers = { "X-Test-User-Id": USER_ID };
  let createdItemId: string;

  test("POST /api/v1/items - should create an item", async ({ request }) => {
    const response = await request.post("/api/v1/items", {
      headers,
      data: {
        title: "Unique Title Item",
        description: "First item",
        visibility: "privateAccess",
      },
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    const validated = ItemResponseSchema.parse(body);
    expect(validated.title).toBe("Unique Title Item");
    createdItemId = validated.id;
  });

  test("POST /api/v1/items - should reject duplicate title with 409", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/items", {
      headers,
      data: {
        title: "Unique Title Item",
        description: "Duplicate item",
        visibility: "privateAccess",
      },
    });

    expect(response.status()).toBe(409);
    const body = await response.json();
    expect(body.error).toContain("already exists");
  });

  test("POST /api/v1/items - should allow different title", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/items", {
      headers,
      data: {
        title: "Different Title Item",
        description: "Second item",
        visibility: "privateAccess",
      },
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body.title).toBe("Different Title Item");

    // Clean up
    await request.delete(`/api/v1/items/${body.id}`, { headers });
  });

  test("PUT /api/v1/items/{id} - should allow updating to same title (no change)", async ({
    request,
  }) => {
    const response = await request.put(`/api/v1/items/${createdItemId}`, {
      headers,
      data: {
        title: "Unique Title Item",
        description: "Updated description",
      },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.title).toBe("Unique Title Item");
  });

  test("PUT /api/v1/items/{id} - should reject updating to existing title with 409", async ({
    request,
  }) => {
    // Create another item first
    const createResponse = await request.post("/api/v1/items", {
      headers,
      data: {
        title: "Another Item",
        visibility: "privateAccess",
      },
    });
    expect(createResponse.status()).toBe(201);
    const anotherItem = await createResponse.json();

    // Try to update it to have the same title as the first item
    const response = await request.put(`/api/v1/items/${anotherItem.id}`, {
      headers,
      data: {
        title: "Unique Title Item",
      },
    });

    expect(response.status()).toBe(409);
    const body = await response.json();
    expect(body.error).toContain("already exists");

    // Clean up
    await request.delete(`/api/v1/items/${anotherItem.id}`, { headers });
  });

  test("POST /api/v1/items - different user can use same title", async ({
    request,
  }) => {
    const otherUserHeaders = {
      "X-Test-User-Id": `other-user-${crypto.randomUUID()}`,
    };

    const response = await request.post("/api/v1/items", {
      headers: otherUserHeaders,
      data: {
        title: "Unique Title Item",
        description: "Same title, different user",
        visibility: "privateAccess",
      },
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body.title).toBe("Unique Title Item");

    // Clean up
    await request.delete(`/api/v1/items/${body.id}`, {
      headers: otherUserHeaders,
    });
  });

  test("POST /api/v1/items - should allow reusing title after deletion", async ({
    request,
  }) => {
    // Delete the first item
    const deleteResponse = await request.delete(
      `/api/v1/items/${createdItemId}`,
      { headers },
    );
    expect(deleteResponse.status()).toBe(204);

    // Create a new item with the same title
    const response = await request.post("/api/v1/items", {
      headers,
      data: {
        title: "Unique Title Item",
        description: "Reused title after deletion",
        visibility: "privateAccess",
      },
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body.title).toBe("Unique Title Item");

    // Clean up
    await request.delete(`/api/v1/items/${body.id}`, { headers });
  });
});
