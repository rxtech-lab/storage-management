import { test, expect } from "@playwright/test";
import {
  ItemResponseSchema,
  ItemDetailResponseSchema,
} from "@/lib/schemas/items";

test.describe.serial("Items API - Date Fields (itemDate, expiresAt)", () => {
  let createdItemId: string;

  test("POST /api/v1/items - should create item with date fields as ISO strings", async ({
    request,
  }) => {
    const itemDate = "2025-06-15T10:00:00.000Z";
    const expiresAt = "2026-12-31T23:59:59.000Z";

    const response = await request.post("/api/v1/items", {
      data: {
        title: "Item with Dates",
        visibility: "privateAccess",
        itemDate,
        expiresAt,
      },
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    const validated = ItemResponseSchema.parse(body);

    expect(validated.itemDate).not.toBeNull();
    expect(validated.expiresAt).not.toBeNull();
    expect(new Date(validated.itemDate!).toISOString()).toBe(itemDate);
    expect(new Date(validated.expiresAt!).toISOString()).toBe(expiresAt);

    createdItemId = validated.id;
  });

  test("PUT /api/v1/items/{id} - should update item with date strings (the getTime bug)", async ({
    request,
  }) => {
    const newItemDate = "2025-09-01T08:00:00.000Z";
    const newExpiresAt = "2027-03-15T12:00:00.000Z";

    const response = await request.put(`/api/v1/items/${createdItemId}`, {
      data: {
        itemDate: newItemDate,
        expiresAt: newExpiresAt,
      },
    });

    // This was previously failing with "value.getTime is not a function"
    expect(response.status()).toBe(200);
    const body = await response.json();
    const validated = ItemResponseSchema.parse(body);

    expect(new Date(validated.itemDate!).toISOString()).toBe(newItemDate);
    expect(new Date(validated.expiresAt!).toISOString()).toBe(newExpiresAt);
  });

  test("PUT /api/v1/items/{id} - should update item with null date fields", async ({
    request,
  }) => {
    const response = await request.put(`/api/v1/items/${createdItemId}`, {
      data: {
        itemDate: null,
        expiresAt: null,
      },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    const validated = ItemResponseSchema.parse(body);

    expect(validated.itemDate).toBeNull();
    expect(validated.expiresAt).toBeNull();
  });

  test("PUT /api/v1/items/{id} - should update only one date field without affecting the other", async ({
    request,
  }) => {
    // First set both dates
    const itemDate = "2025-06-15T10:00:00.000Z";
    await request.put(`/api/v1/items/${createdItemId}`, {
      data: { itemDate, expiresAt: "2027-01-01T00:00:00.000Z" },
    });

    // Update only expiresAt
    const newExpiresAt = "2028-06-01T00:00:00.000Z";
    const response = await request.put(`/api/v1/items/${createdItemId}`, {
      data: { expiresAt: newExpiresAt },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    const validated = ItemResponseSchema.parse(body);

    // itemDate should remain unchanged
    expect(new Date(validated.itemDate!).toISOString()).toBe(itemDate);
    expect(new Date(validated.expiresAt!).toISOString()).toBe(newExpiresAt);
  });

  test("GET /api/v1/items/{id} - should return date fields in detail response", async ({
    request,
  }) => {
    const response = await request.get(`/api/v1/items/${createdItemId}`);

    expect(response.status()).toBe(200);
    const body = await response.json();
    const validated = ItemDetailResponseSchema.parse(body);

    expect(validated.itemDate).toBeDefined();
    expect(validated.expiresAt).toBeDefined();
  });

  test("PUT /api/v1/items/{id} - should reject invalid date strings", async ({
    request,
  }) => {
    const response = await request.put(`/api/v1/items/${createdItemId}`, {
      data: {
        itemDate: "not-a-date",
      },
    });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body).toHaveProperty("error");
  });

  // Cleanup
  test("DELETE /api/v1/items/{id} - cleanup", async ({ request }) => {
    const response = await request.delete(`/api/v1/items/${createdItemId}`);
    expect(response.status()).toBe(204);
  });
});
