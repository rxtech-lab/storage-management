import { test, expect } from "@playwright/test";

/**
 * Permission tests for multi-user scenarios.
 * Uses X-Test-User-Id header to simulate different users.
 */
test.describe.serial("Permission Tests", () => {
  // Use randomized user IDs to avoid conflicts with data from previous test runs
  const USER_1 = `test-user-1-${crypto.randomUUID()}`;
  const USER_2 = `test-user-2-${crypto.randomUUID()}`;

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
      user1LocationId = body.id;
    });

    test("should create author", async ({ request }) => {
      const response = await request.post("/api/v1/authors", {
        headers: { "X-Test-User-Id": USER_1 },
        data: { name: "User1 Author", bio: "Author owned by user 1" },
      });
      expect(response.status()).toBe(201);
      const body = await response.json();
      user1AuthorId = body.id;
    });

    test("should create private item", async ({ request }) => {
      const response = await request.post("/api/v1/items", {
        headers: { "X-Test-User-Id": USER_1 },
        data: {
          title: "User1 Private Item",
          description: "Private item owned by user 1",
          visibility: "privateAccess",
          categoryId: user1CategoryId,
          locationId: user1LocationId,
          authorId: user1AuthorId,
        },
      });
      expect(response.status()).toBe(201);
      const body = await response.json();
      user1ItemId = body.id;
    });
  });

  test.describe("User 2 cannot access User 1 private resources", () => {
    test("should not see User 1 private item in list", async ({ request }) => {
      const response = await request.get("/api/v1/items", {
        headers: { "X-Test-User-Id": USER_2 },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      const user1Items = body.data.filter((item: any) => item.id === user1ItemId);
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
      const user1Locations = body.filter((l: any) => l.id === user1LocationId);
      expect(user1Locations.length).toBe(0);
    });

    test("should not see User 1 author in list", async ({ request }) => {
      const response = await request.get("/api/v1/authors", {
        headers: { "X-Test-User-Id": USER_2 },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      const user1Authors = body.filter((a: any) => a.id === user1AuthorId);
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
        data: { visibility: "publicAccess" },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      expect(body.visibility).toBe("publicAccess");
    });
  });

  test.describe("User 2 can view but not modify public items", () => {
    test("should NOT see User 1 public item in list (users only see their own items)", async ({ request }) => {
      const response = await request.get("/api/v1/items", {
        headers: { "X-Test-User-Id": USER_2 },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      // List endpoint returns only user's own items, not other users' public items
      const user1Items = body.data.filter((item: any) => item.id === user1ItemId);
      expect(user1Items.length).toBe(0);
    });

    test("should access User 1 public item by ID (direct access still works)", async ({ request }) => {
      const response = await request.get(`/api/v1/items/${user1ItemId}`, {
        headers: { "X-Test-User-Id": USER_2 },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      expect(body.id).toBe(user1ItemId);
      expect(body.visibility).toBe("publicAccess");
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
      expect(response.status()).toBe(204);
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

/**
 * Multi-user item isolation tests.
 * Verifies that users can only see their own private items and all public items.
 */
test.describe.serial("Multi-User Item Isolation", () => {
  // Use randomized user IDs to avoid conflicts with data from previous test runs
  const USER_A = `isolation-user-a-${crypto.randomUUID()}`;
  const USER_A_EMAIL = `user-a-${crypto.randomUUID()}@example.com`;
  const USER_B = `isolation-user-b-${crypto.randomUUID()}`;
  const USER_B_EMAIL = `user-b-${crypto.randomUUID()}@example.com`;
  const USER_C = `isolation-user-c-${crypto.randomUUID()}`;
  const USER_C_EMAIL = `user-c-${crypto.randomUUID()}@example.com`;

  // Track created item IDs
  let userAPrivateItem1Id: number;
  let userAPrivateItem2Id: number;
  let userAPublicItemId: number;
  let userBPrivateItemId: number;
  let userBPublicItemId: number;
  let userCPrivateItemId: number;

  test.describe("Setup - Create items for multiple users", () => {
    test("User A creates 2 private items and 1 public item", async ({ request }) => {
      // Create private item 1
      const response1 = await request.post("/api/v1/items", {
        headers: { "X-Test-User-Id": USER_A, "X-Test-User-Email": USER_A_EMAIL },
        data: {
          title: "User A Private Item 1",
          description: "First private item belonging to User A",
          visibility: "privateAccess",
        },
      });
      expect(response1.status()).toBe(201);
      userAPrivateItem1Id = (await response1.json()).id;

      // Create private item 2
      const response2 = await request.post("/api/v1/items", {
        headers: { "X-Test-User-Id": USER_A, "X-Test-User-Email": USER_A_EMAIL },
        data: {
          title: "User A Private Item 2",
          description: "Second private item belonging to User A",
          visibility: "privateAccess",
        },
      });
      expect(response2.status()).toBe(201);
      userAPrivateItem2Id = (await response2.json()).id;

      // Create public item
      const response3 = await request.post("/api/v1/items", {
        headers: { "X-Test-User-Id": USER_A, "X-Test-User-Email": USER_A_EMAIL },
        data: {
          title: "User A Public Item",
          description: "Public item belonging to User A",
          visibility: "publicAccess",
        },
      });
      expect(response3.status()).toBe(201);
      userAPublicItemId = (await response3.json()).id;
    });

    test("User B creates 1 private item and 1 public item", async ({ request }) => {
      // Create private item
      const response1 = await request.post("/api/v1/items", {
        headers: { "X-Test-User-Id": USER_B, "X-Test-User-Email": USER_B_EMAIL },
        data: {
          title: "User B Private Item",
          description: "Private item belonging to User B",
          visibility: "privateAccess",
        },
      });
      expect(response1.status()).toBe(201);
      userBPrivateItemId = (await response1.json()).id;

      // Create public item
      const response2 = await request.post("/api/v1/items", {
        headers: { "X-Test-User-Id": USER_B, "X-Test-User-Email": USER_B_EMAIL },
        data: {
          title: "User B Public Item",
          description: "Public item belonging to User B",
          visibility: "publicAccess",
        },
      });
      expect(response2.status()).toBe(201);
      userBPublicItemId = (await response2.json()).id;
    });

    test("User C creates 1 private item", async ({ request }) => {
      const response = await request.post("/api/v1/items", {
        headers: { "X-Test-User-Id": USER_C, "X-Test-User-Email": USER_C_EMAIL },
        data: {
          title: "User C Private Item",
          description: "Private item belonging to User C",
          visibility: "privateAccess",
        },
      });
      expect(response.status()).toBe(201);
      userCPrivateItemId = (await response.json()).id;
    });
  });

  test.describe("List isolation verification", () => {
    test("User A sees ONLY their own items (not other users' public items)", async ({ request }) => {
      const response = await request.get("/api/v1/items", {
        headers: { "X-Test-User-Id": USER_A, "X-Test-User-Email": USER_A_EMAIL },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      const itemTitles = body.data.map((item: any) => item.title);

      // User A should see their own items (3 total)
      expect(itemTitles).toContain("User A Private Item 1");
      expect(itemTitles).toContain("User A Private Item 2");
      expect(itemTitles).toContain("User A Public Item");

      // User A should NOT see other users' items (not even public ones)
      expect(itemTitles).not.toContain("User B Public Item");
      expect(itemTitles).not.toContain("User B Private Item");
      expect(itemTitles).not.toContain("User C Private Item");
    });

    test("User B sees ONLY their own items (not other users' public items)", async ({ request }) => {
      const response = await request.get("/api/v1/items", {
        headers: { "X-Test-User-Id": USER_B, "X-Test-User-Email": USER_B_EMAIL },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      const itemTitles = body.data.map((item: any) => item.title);

      // User B should see their own items (2 total)
      expect(itemTitles).toContain("User B Private Item");
      expect(itemTitles).toContain("User B Public Item");

      // User B should NOT see other users' items (not even public ones)
      expect(itemTitles).not.toContain("User A Public Item");
      expect(itemTitles).not.toContain("User A Private Item 1");
      expect(itemTitles).not.toContain("User A Private Item 2");
      expect(itemTitles).not.toContain("User C Private Item");
    });

    test("User C sees ONLY their own items (not other users' public items)", async ({ request }) => {
      const response = await request.get("/api/v1/items", {
        headers: { "X-Test-User-Id": USER_C, "X-Test-User-Email": USER_C_EMAIL },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      const itemTitles = body.data.map((item: any) => item.title);

      // User C should see their own item (1 total)
      expect(itemTitles).toContain("User C Private Item");

      // User C should NOT see other users' items (not even public ones)
      expect(itemTitles).not.toContain("User A Public Item");
      expect(itemTitles).not.toContain("User B Public Item");
      expect(itemTitles).not.toContain("User A Private Item 1");
      expect(itemTitles).not.toContain("User A Private Item 2");
      expect(itemTitles).not.toContain("User B Private Item");
    });
  });

  test.describe("Direct access denial verification", () => {
    test("User B cannot access User A's private items by ID", async ({ request }) => {
      const response1 = await request.get(`/api/v1/items/${userAPrivateItem1Id}`, {
        headers: { "X-Test-User-Id": USER_B, "X-Test-User-Email": USER_B_EMAIL },
      });
      expect(response1.status()).toBe(403);
      const body1 = await response1.json();
      expect(body1.error).toBe("Permission denied");

      const response2 = await request.get(`/api/v1/items/${userAPrivateItem2Id}`, {
        headers: { "X-Test-User-Id": USER_B, "X-Test-User-Email": USER_B_EMAIL },
      });
      expect(response2.status()).toBe(403);
    });

    test("User C cannot access User A's or User B's private items", async ({ request }) => {
      const responseA1 = await request.get(`/api/v1/items/${userAPrivateItem1Id}`, {
        headers: { "X-Test-User-Id": USER_C, "X-Test-User-Email": USER_C_EMAIL },
      });
      expect(responseA1.status()).toBe(403);

      const responseA2 = await request.get(`/api/v1/items/${userAPrivateItem2Id}`, {
        headers: { "X-Test-User-Id": USER_C, "X-Test-User-Email": USER_C_EMAIL },
      });
      expect(responseA2.status()).toBe(403);

      const responseB = await request.get(`/api/v1/items/${userBPrivateItemId}`, {
        headers: { "X-Test-User-Id": USER_C, "X-Test-User-Email": USER_C_EMAIL },
      });
      expect(responseB.status()).toBe(403);
    });

    test("User A cannot access User B's or User C's private items", async ({ request }) => {
      const responseB = await request.get(`/api/v1/items/${userBPrivateItemId}`, {
        headers: { "X-Test-User-Id": USER_A, "X-Test-User-Email": USER_A_EMAIL },
      });
      expect(responseB.status()).toBe(403);

      const responseC = await request.get(`/api/v1/items/${userCPrivateItemId}`, {
        headers: { "X-Test-User-Id": USER_A, "X-Test-User-Email": USER_A_EMAIL },
      });
      expect(responseC.status()).toBe(403);
    });
  });

  test.describe("Ownership verification in list response", () => {
    test("All items in User A's list belong to User A only", async ({ request }) => {
      const response = await request.get("/api/v1/items", {
        headers: { "X-Test-User-Id": USER_A, "X-Test-User-Email": USER_A_EMAIL },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();

      // Filter to only our test items by title prefix
      const testItems = body.data.filter((item: any) =>
        item.title.startsWith("User A ")
      );

      // Verify each item has userId field and belongs to User A
      for (const item of testItems) {
        expect(item.userId).toBeDefined();
        expect(item.userId).toBe(USER_A);
      }

      // Verify User B's items are NOT in the list
      const userBItems = body.data.filter((item: any) =>
        item.title.startsWith("User B ")
      );
      expect(userBItems.length).toBe(0);
    });

    test("All items in list always belong to requesting user", async ({ request }) => {
      const response = await request.get("/api/v1/items", {
        headers: { "X-Test-User-Id": USER_B, "X-Test-User-Email": USER_B_EMAIL },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();

      // All items in the list should belong to User B
      for (const item of body.data) {
        expect(item.userId).toBe(USER_B);
      }
    });
  });

  test.describe("Visibility filter verification", () => {
    test("Filtering by visibility=privateAccess returns only own private items", async ({ request }) => {
      const response = await request.get("/api/v1/items?visibility=privateAccess", {
        headers: { "X-Test-User-Id": USER_A, "X-Test-User-Email": USER_A_EMAIL },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      const itemTitles = body.data.map((item: any) => item.title);

      // Should see User A's private items
      expect(itemTitles).toContain("User A Private Item 1");
      expect(itemTitles).toContain("User A Private Item 2");

      // Verify none of other users' private items appear
      expect(itemTitles).not.toContain("User B Private Item");
      expect(itemTitles).not.toContain("User C Private Item");

      // All returned items should be User A's private items
      const userAPrivateItems = body.data.filter((item: any) =>
        item.title.startsWith("User A Private")
      );
      expect(userAPrivateItems.length).toBe(2);
    });
  });

  test.describe("Cleanup - Delete all test items", () => {
    test("User A deletes their items", async ({ request }) => {
      for (const id of [userAPrivateItem1Id, userAPrivateItem2Id, userAPublicItemId]) {
        const response = await request.delete(`/api/v1/items/${id}`, {
          headers: { "X-Test-User-Id": USER_A, "X-Test-User-Email": USER_A_EMAIL },
        });
        expect(response.status()).toBe(204);
      }
    });

    test("User B deletes their items", async ({ request }) => {
      for (const id of [userBPrivateItemId, userBPublicItemId]) {
        const response = await request.delete(`/api/v1/items/${id}`, {
          headers: { "X-Test-User-Id": USER_B, "X-Test-User-Email": USER_B_EMAIL },
        });
        expect(response.status()).toBe(204);
      }
    });

    test("User C deletes their item", async ({ request }) => {
      const response = await request.delete(`/api/v1/items/${userCPrivateItemId}`, {
        headers: { "X-Test-User-Id": USER_C, "X-Test-User-Email": USER_C_EMAIL },
      });
      expect(response.status()).toBe(204);
    });
  });
});
