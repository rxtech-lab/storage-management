import { test, expect } from "@playwright/test";

test.describe.serial("Categories API", () => {
  let createdCategoryId: number;

  test("POST /api/v1/categories - should create a new category", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/categories", {
      data: {
        name: "Test Category",
        description: "Created via API test",
      },
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body).toHaveProperty("id");
    expect(body.name).toBe("Test Category");
    expect(body.description).toBe("Created via API test");

    createdCategoryId = body.id;
  });

  test("GET /api/v1/categories - should list all categories", async ({
    request,
  }) => {
    const response = await request.get("/api/v1/categories");

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body).toBeInstanceOf(Array);
    expect(body.length).toBeGreaterThan(0);
  });

  test("GET /api/v1/categories/{id} - should get category by ID", async ({
    request,
  }) => {
    const response = await request.get(
      `/api/v1/categories/${createdCategoryId}`,
    );

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.id).toBe(createdCategoryId);
    expect(body.name).toBe("Test Category");
  });

  test("PUT /api/v1/categories/{id} - should update category", async ({
    request,
  }) => {
    const response = await request.put(
      `/api/v1/categories/${createdCategoryId}`,
      {
        data: {
          name: "Updated Category",
          description: "Updated via API test",
        },
      },
    );

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.name).toBe("Updated Category");
  });

  test("DELETE /api/v1/categories/{id} - should delete category", async ({
    request,
  }) => {
    const response = await request.delete(
      `/api/v1/categories/${createdCategoryId}`,
    );

    expect(response.status()).toBe(200);

    // Verify category is deleted
    const getResponse = await request.get(
      `/api/v1/categories/${createdCategoryId}`,
    );
    expect(getResponse.status()).toBe(404);
  });

  test("POST /api/v1/categories - should validate required fields", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/categories", {
      data: {
        description: "Missing name",
      },
    });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body).toHaveProperty("error");
  });
});

test.describe.serial("Categories API - Multi-user Isolation", () => {
  const USER_1 = "category-test-user-1";
  const USER_2 = "category-test-user-2";
  let user1CategoryId: number;

  test("User 1 creates a category", async ({ request }) => {
    const response = await request.post("/api/v1/categories", {
      headers: { "X-Test-User-Id": USER_1 },
      data: {
        name: "User1 Category",
        description: "Owned by user 1",
      },
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body.name).toBe("User1 Category");
    user1CategoryId = body.id;
  });

  test("User 2 cannot see User 1 category in list", async ({ request }) => {
    const response = await request.get("/api/v1/categories", {
      headers: { "X-Test-User-Id": USER_2 },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body).toBeInstanceOf(Array);
    const user1Categories = body.filter(
      (c: { id: number }) => c.id === user1CategoryId,
    );
    expect(user1Categories.length).toBe(0);
  });

  test("User 2 gets 403 when accessing User 1 category by ID", async ({
    request,
  }) => {
    const response = await request.get(
      `/api/v1/categories/${user1CategoryId}`,
      {
        headers: { "X-Test-User-Id": USER_2 },
      },
    );

    expect(response.status()).toBe(403);
    const body = await response.json();
    expect(body.error).toBe("Permission denied");
  });

  test("User 2 gets 403 when updating User 1 category", async ({ request }) => {
    const response = await request.put(
      `/api/v1/categories/${user1CategoryId}`,
      {
        headers: { "X-Test-User-Id": USER_2 },
        data: {
          name: "Hacked Category",
        },
      },
    );

    expect(response.status()).toBe(403);
    const body = await response.json();
    expect(body.error).toBe("Permission denied");
  });

  test("User 2 gets 403 when deleting User 1 category", async ({ request }) => {
    const response = await request.delete(
      `/api/v1/categories/${user1CategoryId}`,
      {
        headers: { "X-Test-User-Id": USER_2 },
      },
    );

    expect(response.status()).toBe(403);
    const body = await response.json();
    expect(body.error).toBe("Permission denied");
  });

  test("User 1 can still access their own category", async ({ request }) => {
    const response = await request.get(
      `/api/v1/categories/${user1CategoryId}`,
      {
        headers: { "X-Test-User-Id": USER_1 },
      },
    );

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.id).toBe(user1CategoryId);
    expect(body.name).toBe("User1 Category");
  });

  test("User 1 can update their own category", async ({ request }) => {
    const response = await request.put(
      `/api/v1/categories/${user1CategoryId}`,
      {
        headers: { "X-Test-User-Id": USER_1 },
        data: {
          name: "User1 Updated Category",
        },
      },
    );

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.name).toBe("User1 Updated Category");
  });

  test("User 1 can delete their own category", async ({ request }) => {
    const response = await request.delete(
      `/api/v1/categories/${user1CategoryId}`,
      {
        headers: { "X-Test-User-Id": USER_1 },
      },
    );

    expect(response.status()).toBe(200);

    // Verify category is deleted
    const getResponse = await request.get(
      `/api/v1/categories/${user1CategoryId}`,
      {
        headers: { "X-Test-User-Id": USER_1 },
      },
    );
    expect(getResponse.status()).toBe(404);
  });
});
