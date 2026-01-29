import { test, expect } from "@playwright/test";

/**
 * Permission tests for multi-user scenarios.
 * Uses X-Test-User-Id header to simulate different users.
 */
test.describe.serial("Permission Tests", () => {
  const USER_1 = "test-user-1";
  const USER_2 = "test-user-2";

  let user1ItemId: number;
  let user1CategoryId: number;
  let user1LocationId: number;
  let user1AuthorId: number;

  test.describe("User 1 creates resources", () => {
    test("should create category", async ({ request }) => {
      const response = await request.post("/api/v1/categories", {
        headers: { "X-Test-User-Id": USER_1 },
        data: { name: "User1 Category", description: "Owned by user 1" },
      });
      expect(response.status()).toBe(201);
      const body = await response.json();
      user1CategoryId = body.id;
    });

    test("should create location", async ({ request }) => {
      const response = await request.post("/api/v1/locations", {
        headers: { "X-Test-User-Id": USER_1 },
        data: { title: "User1 Location", latitude: 40.7128, longitude: -74.006 },
      });
      expect(response.status()).toBe(201);
      const body = await response.json();
      user1LocationId = body.data.id;
    });

    test("should create author", async ({ request }) => {
      const response = await request.post("/api/v1/authors", {
        headers: { "X-Test-User-Id": USER_1 },
        data: { name: "User1 Author", bio: "Author owned by user 1" },
      });
      expect(response.status()).toBe(201);
      const body = await response.json();
      user1AuthorId = body.data.id;
    });

    test("should create private item", async ({ request }) => {
      const response = await request.post("/api/v1/items", {
        headers: { "X-Test-User-Id": USER_1 },
        data: {
          title: "User1 Private Item",
          description: "Private item owned by user 1",
          visibility: "private",
          categoryId: user1CategoryId,
          locationId: user1LocationId,
          authorId: user1AuthorId,
        },
      });
      expect(response.status()).toBe(201);
      const body = await response.json();
      user1ItemId = body.data.id;
    });
  });

  test.describe("User 2 cannot access User 1 private resources", () => {
    test("should not see User 1 private item in list", async ({ request }) => {
      const response = await request.get("/api/v1/items", {
        headers: { "X-Test-User-Id": USER_2 },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      const user1Items = body.filter((item: any) => item.id === user1ItemId);
      expect(user1Items.length).toBe(0);
    });

    test("should not see User 1 category in list", async ({ request }) => {
      const response = await request.get("/api/v1/categories", {
        headers: { "X-Test-User-Id": USER_2 },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      const user1Categories = body.filter((c: any) => c.id === user1CategoryId);
      expect(user1Categories.length).toBe(0);
    });

    test("should not see User 1 location in list", async ({ request }) => {
      const response = await request.get("/api/v1/locations", {
        headers: { "X-Test-User-Id": USER_2 },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      const user1Locations = body.data.filter((l: any) => l.id === user1LocationId);
      expect(user1Locations.length).toBe(0);
    });

    test("should not see User 1 author in list", async ({ request }) => {
      const response = await request.get("/api/v1/authors", {
        headers: { "X-Test-User-Id": USER_2 },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      const user1Authors = body.data.filter((a: any) => a.id === user1AuthorId);
      expect(user1Authors.length).toBe(0);
    });

    test("should get 403 when accessing User 1 private item by ID", async ({ request }) => {
      const response = await request.get(`/api/v1/items/${user1ItemId}`, {
        headers: { "X-Test-User-Id": USER_2 },
      });
      expect(response.status()).toBe(403);
    });

    test("should get 403 when accessing User 1 category by ID", async ({ request }) => {
      const response = await request.get(`/api/v1/categories/${user1CategoryId}`, {
        headers: { "X-Test-User-Id": USER_2 },
      });
      expect(response.status()).toBe(403);
    });

    test("should get 403 when accessing User 1 location by ID", async ({ request }) => {
      const response = await request.get(`/api/v1/locations/${user1LocationId}`, {
        headers: { "X-Test-User-Id": USER_2 },
      });
      expect(response.status()).toBe(403);
    });

    test("should get 403 when accessing User 1 author by ID", async ({ request }) => {
      const response = await request.get(`/api/v1/authors/${user1AuthorId}`, {
        headers: { "X-Test-User-Id": USER_2 },
      });
      expect(response.status()).toBe(403);
    });

    test("should get 403 when trying to update User 1 item", async ({ request }) => {
      const response = await request.put(`/api/v1/items/${user1ItemId}`, {
        headers: { "X-Test-User-Id": USER_2 },
        data: { title: "Hacked Item" },
      });
      expect(response.status()).toBe(403);
    });

    test("should get 403 when trying to update User 1 category", async ({ request }) => {
      const response = await request.put(`/api/v1/categories/${user1CategoryId}`, {
        headers: { "X-Test-User-Id": USER_2 },
        data: { name: "Hacked Category" },
      });
      expect(response.status()).toBe(403);
    });

    test("should get 403 when trying to update User 1 location", async ({ request }) => {
      const response = await request.put(`/api/v1/locations/${user1LocationId}`, {
        headers: { "X-Test-User-Id": USER_2 },
        data: { title: "Hacked Location" },
      });
      expect(response.status()).toBe(403);
    });

    test("should get 403 when trying to update User 1 author", async ({ request }) => {
      const response = await request.put(`/api/v1/authors/${user1AuthorId}`, {
        headers: { "X-Test-User-Id": USER_2 },
        data: { name: "Hacked Author" },
      });
      expect(response.status()).toBe(403);
    });

    test("should get 403 when trying to delete User 1 item", async ({ request }) => {
      const response = await request.delete(`/api/v1/items/${user1ItemId}`, {
        headers: { "X-Test-User-Id": USER_2 },
      });
      expect(response.status()).toBe(403);
    });

    test("should get 403 when trying to delete User 1 category", async ({ request }) => {
      const response = await request.delete(`/api/v1/categories/${user1CategoryId}`, {
        headers: { "X-Test-User-Id": USER_2 },
      });
      expect(response.status()).toBe(403);
    });

    test("should get 403 when trying to delete User 1 location", async ({ request }) => {
      const response = await request.delete(`/api/v1/locations/${user1LocationId}`, {
        headers: { "X-Test-User-Id": USER_2 },
      });
      expect(response.status()).toBe(403);
    });

    test("should get 403 when trying to delete User 1 author", async ({ request }) => {
      const response = await request.delete(`/api/v1/authors/${user1AuthorId}`, {
        headers: { "X-Test-User-Id": USER_2 },
      });
      expect(response.status()).toBe(403);
    });
  });

  test.describe("User 1 makes item public", () => {
    test("should update item to public", async ({ request }) => {
      const response = await request.put(`/api/v1/items/${user1ItemId}`, {
        headers: { "X-Test-User-Id": USER_1 },
        data: { visibility: "public" },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      expect(body.data.visibility).toBe("public");
    });
  });

  test.describe("User 2 can view but not modify public items", () => {
    test("should see User 1 public item in list", async ({ request }) => {
      const response = await request.get("/api/v1/items", {
        headers: { "X-Test-User-Id": USER_2 },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      const user1Items = body.filter((item: any) => item.id === user1ItemId);
      expect(user1Items.length).toBe(1);
      expect(user1Items[0].visibility).toBe("public");
    });

    test("should access User 1 public item by ID", async ({ request }) => {
      const response = await request.get(`/api/v1/items/${user1ItemId}`, {
        headers: { "X-Test-User-Id": USER_2 },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      expect(body.data.id).toBe(user1ItemId);
      expect(body.data.visibility).toBe("public");
    });

    test("should still get 403 when trying to update public item", async ({ request }) => {
      const response = await request.put(`/api/v1/items/${user1ItemId}`, {
        headers: { "X-Test-User-Id": USER_2 },
        data: { title: "Hacked Public Item" },
      });
      expect(response.status()).toBe(403);
    });

    test("should still get 403 when trying to delete public item", async ({ request }) => {
      const response = await request.delete(`/api/v1/items/${user1ItemId}`, {
        headers: { "X-Test-User-Id": USER_2 },
      });
      expect(response.status()).toBe(403);
    });
  });

  test.describe("Cleanup - User 1 deletes resources", () => {
    test("should delete item", async ({ request }) => {
      const response = await request.delete(`/api/v1/items/${user1ItemId}`, {
        headers: { "X-Test-User-Id": USER_1 },
      });
      expect(response.status()).toBe(200);
    });

    test("should delete category", async ({ request }) => {
      const response = await request.delete(`/api/v1/categories/${user1CategoryId}`, {
        headers: { "X-Test-User-Id": USER_1 },
      });
      expect(response.status()).toBe(200);
    });

    test("should delete location", async ({ request }) => {
      const response = await request.delete(`/api/v1/locations/${user1LocationId}`, {
        headers: { "X-Test-User-Id": USER_1 },
      });
      expect(response.status()).toBe(200);
    });

    test("should delete author", async ({ request }) => {
      const response = await request.delete(`/api/v1/authors/${user1AuthorId}`, {
        headers: { "X-Test-User-Id": USER_1 },
      });
      expect(response.status()).toBe(200);
    });
  });
});
