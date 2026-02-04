import { test, expect, APIRequestContext } from "@playwright/test";

/**
 * Tests that the items list API returns only the authenticated user's items.
 * Users should NOT see other users' items regardless of visibility setting.
 */
test.describe.serial("Items List User Isolation", () => {
  // Randomized user IDs to avoid conflicts with other tests
  const USER_A = `user-a-${crypto.randomUUID()}`;
  const USER_B = `user-b-${crypto.randomUUID()}`;

  // Track created item IDs
  const userAItemIds: number[] = [];
  const userBItemIds: number[] = [];

  // Helper to create items
  async function createItem(
    request: APIRequestContext,
    userId: string,
    title: string,
    visibility: string,
  ) {
    const response = await request.post("/api/v1/items", {
      headers: { "X-Test-User-Id": userId },
      data: {
        title,
        description: `${visibility} item`,
        visibility,
      },
    });
    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body.id).toBeDefined();
    return body.id;
  }

  test.beforeAll(async ({ request }) => {
    // User A: 2 private items
    for (let i = 1; i <= 2; i++) {
      userAItemIds.push(
        await createItem(
          request,
          USER_A,
          `User A Private Item ${i}`,
          "privateAccess",
        ),
      );
    }

    // User A: 3 public items
    for (let i = 1; i <= 3; i++) {
      userAItemIds.push(
        await createItem(
          request,
          USER_A,
          `User A Public Item ${i}`,
          "publicAccess",
        ),
      );
    }

    // User B: 2 private items
    for (let i = 1; i <= 2; i++) {
      userBItemIds.push(
        await createItem(
          request,
          USER_B,
          `User B Private Item ${i}`,
          "privateAccess",
        ),
      );
    }

    // User B: 3 public items
    for (let i = 1; i <= 3; i++) {
      userBItemIds.push(
        await createItem(
          request,
          USER_B,
          `User B Public Item ${i}`,
          "publicAccess",
        ),
      );
    }
  });

  test("User B should only see their own 5 items in list", async ({
    request,
  }) => {
    const response = await request.get("/api/v1/items", {
      headers: { "X-Test-User-Id": USER_B },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();

    expect(body.data).toBeDefined();
    expect(Array.isArray(body.data)).toBe(true);

    // User B should see exactly 5 items (their own)
    expect(body.data.length).toBe(5);

    // All returned items should belong to User B
    const returnedIds = body.data.map((item: { id: number }) => item.id);
    for (const id of userBItemIds) {
      expect(returnedIds).toContain(id);
    }

    // None of User A's items should be in the response
    for (const id of userAItemIds) {
      expect(returnedIds).not.toContain(id);
    }

    // Verify visibility breakdown: 2 private + 3 public
    const privateItems = body.data.filter(
      (item: { visibility: string }) => item.visibility === "privateAccess",
    );
    const publicItems = body.data.filter(
      (item: { visibility: string }) => item.visibility === "publicAccess",
    );
    expect(privateItems.length).toBe(2);
    expect(publicItems.length).toBe(3);
  });

  test("User A should only see their own 5 items in list", async ({
    request,
  }) => {
    const response = await request.get("/api/v1/items", {
      headers: { "X-Test-User-Id": USER_A },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();

    expect(body.data).toBeDefined();
    expect(Array.isArray(body.data)).toBe(true);

    // User A should see exactly 5 items (their own)
    expect(body.data.length).toBe(5);

    // All returned items should belong to User A
    const returnedIds = body.data.map((item: { id: number }) => item.id);
    for (const id of userAItemIds) {
      expect(returnedIds).toContain(id);
    }

    // None of User B's items should be in the response
    for (const id of userBItemIds) {
      expect(returnedIds).not.toContain(id);
    }

    // Verify visibility breakdown: 2 private + 3 public
    const privateItems = body.data.filter(
      (item: { visibility: string }) => item.visibility === "privateAccess",
    );
    const publicItems = body.data.filter(
      (item: { visibility: string }) => item.visibility === "publicAccess",
    );
    expect(privateItems.length).toBe(2);
    expect(publicItems.length).toBe(3);
  });
});
