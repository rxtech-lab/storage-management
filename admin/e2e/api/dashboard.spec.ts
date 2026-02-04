import { test, expect } from '@playwright/test';
import { DashboardStatsResponseSchema, DashboardRecentItemSchema } from '../../lib/schemas/dashboard';
import { z } from 'zod';

/**
 * Dashboard Statistics User Isolation Tests
 * Verifies that dashboard stats only include the user's own items,
 * NOT other users' items (even if they are public).
 */
test.describe.serial("Dashboard Statistics User Isolation", () => {
  const USER_A = "dashboard-user-a";
  const USER_B = "dashboard-user-b";

  let userAPrivateItemId: number;
  let userAPublicItemId: number;
  let userBPrivateItemId: number;
  let userBPublicItemId: number;

  test.describe("Setup - Create items for different users", () => {
    test("User A creates 1 private and 1 public item", async ({ request }) => {
      // Create private item
      const response1 = await request.post("/api/v1/items", {
        headers: { "X-Test-User-Id": USER_A },
        data: {
          title: "User A Private Item",
          description: "Private item for dashboard test",
          visibility: "privateAccess",
        },
      });
      expect(response1.status()).toBe(201);
      userAPrivateItemId = (await response1.json()).id;

      // Create public item
      const response2 = await request.post("/api/v1/items", {
        headers: { "X-Test-User-Id": USER_A },
        data: {
          title: "User A Public Item",
          description: "Public item for dashboard test",
          visibility: "publicAccess",
        },
      });
      expect(response2.status()).toBe(201);
      userAPublicItemId = (await response2.json()).id;
    });

    test("User B creates 1 private and 1 public item", async ({ request }) => {
      // Create private item
      const response1 = await request.post("/api/v1/items", {
        headers: { "X-Test-User-Id": USER_B },
        data: {
          title: "User B Private Item",
          description: "Private item for dashboard test",
          visibility: "privateAccess",
        },
      });
      expect(response1.status()).toBe(201);
      userBPrivateItemId = (await response1.json()).id;

      // Create public item
      const response2 = await request.post("/api/v1/items", {
        headers: { "X-Test-User-Id": USER_B },
        data: {
          title: "User B Public Item",
          description: "Public item for dashboard test",
          visibility: "publicAccess",
        },
      });
      expect(response2.status()).toBe(201);
      userBPublicItemId = (await response2.json()).id;
    });
  });

  test.describe("Statistics isolation verification", () => {
    test("User A dashboard stats only include their own items (not User B's public items)", async ({ request }) => {
      const response = await request.get("/api/v1/dashboard/stats", {
        headers: { "X-Test-User-Id": USER_A },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();

      // User A has 2 items (1 private + 1 public)
      expect(body.totalItems).toBe(2);
      expect(body.privateItems).toBe(1);
      expect(body.publicItems).toBe(1);

      // recentItems should only contain User A's items
      const recentIds = body.recentItems.map((item: any) => item.id);
      expect(recentIds).toContain(userAPrivateItemId);
      expect(recentIds).toContain(userAPublicItemId);

      // User B's items should NOT appear (even the public one)
      expect(recentIds).not.toContain(userBPrivateItemId);
      expect(recentIds).not.toContain(userBPublicItemId);
    });

    test("User B dashboard stats only include their own items (not User A's public items)", async ({ request }) => {
      const response = await request.get("/api/v1/dashboard/stats", {
        headers: { "X-Test-User-Id": USER_B },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();

      // User B has 2 items (1 private + 1 public)
      expect(body.totalItems).toBe(2);
      expect(body.privateItems).toBe(1);
      expect(body.publicItems).toBe(1);

      // recentItems should only contain User B's items
      const recentIds = body.recentItems.map((item: any) => item.id);
      expect(recentIds).toContain(userBPrivateItemId);
      expect(recentIds).toContain(userBPublicItemId);

      // User A's items should NOT appear (even the public one)
      expect(recentIds).not.toContain(userAPrivateItemId);
      expect(recentIds).not.toContain(userAPublicItemId);
    });

    test("Other users' public items do NOT inflate dashboard counts", async ({ request }) => {
      // User A's stats should not be affected by User B's public items
      const responseA = await request.get("/api/v1/dashboard/stats", {
        headers: { "X-Test-User-Id": USER_A },
      });
      const bodyA = await responseA.json();

      const responseB = await request.get("/api/v1/dashboard/stats", {
        headers: { "X-Test-User-Id": USER_B },
      });
      const bodyB = await responseB.json();

      // Both users should have exactly 2 items each
      expect(bodyA.totalItems).toBe(2);
      expect(bodyB.totalItems).toBe(2);

      // Combined would be 4, but each user only sees their own 2
      expect(bodyA.totalItems + bodyB.totalItems).toBe(4);
    });
  });

  test.describe("Contrast with List Items API", () => {
    test("List items API DOES show other users' public items (unlike dashboard)", async ({ request }) => {
      const response = await request.get("/api/v1/items", {
        headers: { "X-Test-User-Id": USER_A },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();

      // Get titles of items to verify which items are visible
      const itemTitles = body.data.map((item: any) => item.title);

      // User A sees their own items
      expect(itemTitles).toContain("User A Private Item");
      expect(itemTitles).toContain("User A Public Item");

      // User A ALSO sees User B's PUBLIC item (but not private)
      expect(itemTitles).toContain("User B Public Item");
      expect(itemTitles).not.toContain("User B Private Item");
    });
  });

  test.describe("Cleanup - Delete all test items", () => {
    test("User A deletes their items", async ({ request }) => {
      for (const id of [userAPrivateItemId, userAPublicItemId]) {
        const response = await request.delete(`/api/v1/items/${id}`, {
          headers: { "X-Test-User-Id": USER_A },
        });
        expect(response.status()).toBe(204);
      }
    });

    test("User B deletes their items", async ({ request }) => {
      for (const id of [userBPrivateItemId, userBPublicItemId]) {
        const response = await request.delete(`/api/v1/items/${id}`, {
          headers: { "X-Test-User-Id": USER_B },
        });
        expect(response.status()).toBe(204);
      }
    });
  });
});

test.describe('Dashboard API', () => {
  test('GET /api/v1/dashboard/stats - should return valid dashboard stats', async ({ request }) => {
    const response = await request.get('/api/v1/dashboard/stats');

    expect(response.status()).toBe(200);
    const body = await response.json();

    // Validate response against Zod schema
    const result = DashboardStatsResponseSchema.safeParse(body);
    if (!result.success) {
      console.error('Validation errors:', result.error.format());
    }
    expect(result.success).toBe(true);
  });

  test('GET /api/v1/dashboard/stats - should return correct types for counts', async ({ request }) => {
    const response = await request.get('/api/v1/dashboard/stats');

    expect(response.status()).toBe(200);
    const body = await response.json();

    // Validate counts are non-negative integers
    expect(body.totalItems).toBeGreaterThanOrEqual(0);
    expect(body.publicItems).toBeGreaterThanOrEqual(0);
    expect(body.privateItems).toBeGreaterThanOrEqual(0);
    expect(body.totalCategories).toBeGreaterThanOrEqual(0);
    expect(body.totalLocations).toBeGreaterThanOrEqual(0);
    expect(body.totalAuthors).toBeGreaterThanOrEqual(0);

    // Sum of public and private should equal total
    expect(body.publicItems + body.privateItems).toBe(body.totalItems);
  });

  test('GET /api/v1/dashboard/stats - should return valid recent items', async ({ request }) => {
    const response = await request.get('/api/v1/dashboard/stats');

    expect(response.status()).toBe(200);
    const body = await response.json();

    expect(body.recentItems).toBeInstanceOf(Array);
    expect(body.recentItems.length).toBeLessThanOrEqual(5);

    // Validate each recent item against schema
    for (const item of body.recentItems) {
      const result = DashboardRecentItemSchema.safeParse(item);
      if (!result.success) {
        console.error('Item validation errors:', result.error.format());
      }
      expect(result.success).toBe(true);

      // Additional type checks
      expect(['publicAccess', 'privateAccess']).toContain(item.visibility);
      expect(typeof item.id).toBe('number');
      expect(typeof item.title).toBe('string');
    }
  });

  test('GET /api/v1/dashboard/stats - recentItems should be sorted by updatedAt descending', async ({ request }) => {
    const response = await request.get('/api/v1/dashboard/stats');

    expect(response.status()).toBe(200);
    const body = await response.json();

    if (body.recentItems.length > 1) {
      for (let i = 0; i < body.recentItems.length - 1; i++) {
        const current = new Date(body.recentItems[i].updatedAt);
        const next = new Date(body.recentItems[i + 1].updatedAt);
        expect(current.getTime()).toBeGreaterThanOrEqual(next.getTime());
      }
    }
  });
});
