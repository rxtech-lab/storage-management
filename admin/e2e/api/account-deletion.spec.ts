import { test, expect } from "@playwright/test";

test.describe.serial("Account Deletion API", () => {
  // First create some data to delete
  let createdCategoryId: number;
  let createdLocationId: number;
  let createdItemId: number;

  test("Setup: Create test data", async ({ request }) => {
    // Create a category
    const catResponse = await request.post("/api/v1/categories", {
      data: {
        name: "Deletion Test Category",
        description: "Will be deleted",
      },
    });
    expect(catResponse.status()).toBe(201);
    const cat = await catResponse.json();
    createdCategoryId = cat.id;

    // Create a location
    const locResponse = await request.post("/api/v1/locations", {
      data: {
        title: "Deletion Test Location",
        latitude: 0,
        longitude: 0,
      },
    });
    expect(locResponse.status()).toBe(201);
    const loc = await locResponse.json();
    createdLocationId = loc.id;

    // Create an item
    const itemResponse = await request.post("/api/v1/items", {
      data: {
        title: "Deletion Test Item",
        categoryId: createdCategoryId,
        locationId: createdLocationId,
      },
    });
    expect(itemResponse.status()).toBe(201);
    const item = await itemResponse.json();
    createdItemId = item.id;
  });

  test("GET /api/v1/account/delete - should return no pending deletion", async ({
    request,
  }) => {
    const response = await request.get("/api/v1/account/delete");

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.pending).toBe(false);
    expect(body.deletion).toBeNull();
  });

  test("POST /api/v1/account/delete - should request account deletion", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/account/delete");

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body.message).toContain("Account deletion scheduled");
    expect(body.deletion).toBeDefined();
    expect(body.deletion.status).toBe("pending");
    expect(body.deletion.userId).toBeDefined();
    expect(body.deletion.scheduledAt).toBeDefined();
  });

  test("POST /api/v1/account/delete - should reject duplicate deletion request", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/account/delete");

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body.error).toContain("already requested");
  });

  test("GET /api/v1/account/delete - should return pending deletion", async ({
    request,
  }) => {
    const response = await request.get("/api/v1/account/delete");

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.pending).toBe(true);
    expect(body.deletion).toBeDefined();
    expect(body.deletion.status).toBe("pending");
  });

  test("DELETE /api/v1/account/delete - should cancel deletion", async ({
    request,
  }) => {
    const response = await request.delete("/api/v1/account/delete");

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.message).toContain("cancelled");
  });

  test("GET /api/v1/account/delete - should return no pending after cancellation", async ({
    request,
  }) => {
    const response = await request.get("/api/v1/account/delete");

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.pending).toBe(false);
  });

  test("DELETE /api/v1/account/delete - should fail when no pending deletion", async ({
    request,
  }) => {
    const response = await request.delete("/api/v1/account/delete");

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body.error).toContain("No pending account deletion");
  });

  test("Full flow: Request and execute deletion", async ({ request }) => {
    // Request deletion again
    const requestResponse = await request.post("/api/v1/account/delete");
    expect(requestResponse.status()).toBe(201);

    // Execute the deletion via callback (simulating QStash)
    const callbackResponse = await request.post(
      "/api/v1/account/delete/callback",
      {
        data: { userId: "test-user-id" },
      }
    );
    expect(callbackResponse.status()).toBe(200);
    const callbackBody = await callbackResponse.json();
    expect(callbackBody.message).toContain("Account deleted");

    // Verify all data was deleted
    const categoriesResponse = await request.get("/api/v1/categories");
    expect(categoriesResponse.status()).toBe(200);
    const categories = await categoriesResponse.json();
    // Categories should be empty (all user data deleted)
    expect(categories).toEqual([]);

    const locationsResponse = await request.get("/api/v1/locations");
    expect(locationsResponse.status()).toBe(200);
    const locations = await locationsResponse.json();
    expect(locations).toEqual([]);

    const itemsResponse = await request.get("/api/v1/items");
    expect(itemsResponse.status()).toBe(200);
    const items = await itemsResponse.json();
    expect(items).toEqual([]);
  });
});
