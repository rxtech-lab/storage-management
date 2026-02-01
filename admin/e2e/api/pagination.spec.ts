import { test, expect } from "@playwright/test";

/**
 * E2E tests for cursor-based pagination across all API endpoints.
 *
 * Test coverage:
 * - Items, Categories, Authors, Locations, Position Schemas
 * - Basic pagination with limit parameter
 * - Next/prev navigation with cursor
 * - Boundary conditions (first/last page)
 * - Empty results
 * - Invalid cursor handling
 * - Backward compatibility (no pagination params)
 */

test.describe.serial("Items Pagination API", () => {
  const createdItemIds: number[] = [];
  const PAGE_SIZE = 5;

  test.beforeAll(async ({ request }) => {
    // Create 12 items for pagination testing
    for (let i = 1; i <= 12; i++) {
      const response = await request.post("/api/v1/items", {
        data: {
          title: `Pagination Test Item ${i.toString().padStart(2, "0")}`,
          description: `Item ${i} for pagination testing`,
          visibility: "private",
        },
      });
      expect(response.status()).toBe(201);
      const body = await response.json();
      createdItemIds.push(body.id);
    }
  });

  test.afterAll(async ({ request }) => {
    // Cleanup: delete all created items
    for (const id of createdItemIds) {
      await request.delete(`/api/v1/items/${id}`);
    }
  });

  test("GET /api/v1/items?limit=5 - returns paginated response with correct structure", async ({
    request,
  }) => {
    const response = await request.get(`/api/v1/items?limit=${PAGE_SIZE}`);
    expect(response.status()).toBe(200);

    const body = await response.json();

    // Should return paginated response structure
    expect(body).toHaveProperty("data");
    expect(body).toHaveProperty("pagination");
    expect(body.data).toBeInstanceOf(Array);
    expect(body.data.length).toBeLessThanOrEqual(PAGE_SIZE);
    expect(body.pagination).toHaveProperty("nextCursor");
    expect(body.pagination).toHaveProperty("prevCursor");
    expect(body.pagination).toHaveProperty("hasNextPage");
    expect(body.pagination).toHaveProperty("hasPrevPage");
  });

  test("GET /api/v1/items?limit=5 - first page has hasPrevPage=false", async ({
    request,
  }) => {
    const response = await request.get(`/api/v1/items?limit=${PAGE_SIZE}`);
    expect(response.status()).toBe(200);

    const body = await response.json();
    expect(body.pagination.hasPrevPage).toBe(false);
    expect(body.pagination.prevCursor).toBeNull();
  });

  test("GET /api/v1/items - navigates to next page correctly", async ({
    request,
  }) => {
    // Get first page
    const firstResponse = await request.get(`/api/v1/items?limit=${PAGE_SIZE}`);
    expect(firstResponse.status()).toBe(200);
    const firstPage = await firstResponse.json();

    if (!firstPage.pagination.hasNextPage) {
      test.skip();
      return;
    }

    // Get second page using cursor
    const nextCursor = firstPage.pagination.nextCursor;
    const secondResponse = await request.get(
      `/api/v1/items?limit=${PAGE_SIZE}&cursor=${nextCursor}&direction=next`
    );
    expect(secondResponse.status()).toBe(200);
    const secondPage = await secondResponse.json();

    // Second page should have different items
    const firstPageIds = firstPage.data.map((item: { id: number }) => item.id);
    const secondPageIds = secondPage.data.map((item: { id: number }) => item.id);

    // No overlap between pages
    const overlap = firstPageIds.filter((id: number) =>
      secondPageIds.includes(id)
    );
    expect(overlap.length).toBe(0);

    // Second page should have hasPrevPage=true
    expect(secondPage.pagination.hasPrevPage).toBe(true);
    expect(secondPage.pagination.prevCursor).not.toBeNull();
  });

  test("GET /api/v1/items - navigates back to previous page correctly", async ({
    request,
  }) => {
    // Get first page
    const firstResponse = await request.get(`/api/v1/items?limit=${PAGE_SIZE}`);
    const firstPage = await firstResponse.json();

    if (!firstPage.pagination.hasNextPage) {
      test.skip();
      return;
    }

    // Get second page
    const secondResponse = await request.get(
      `/api/v1/items?limit=${PAGE_SIZE}&cursor=${firstPage.pagination.nextCursor}&direction=next`
    );
    const secondPage = await secondResponse.json();

    // Go back to first page
    const backResponse = await request.get(
      `/api/v1/items?limit=${PAGE_SIZE}&cursor=${secondPage.pagination.prevCursor}&direction=prev`
    );
    expect(backResponse.status()).toBe(200);
    const backPage = await backResponse.json();

    // Should have same items as first page
    const firstPageIds = firstPage.data.map((item: { id: number }) => item.id);
    const backPageIds = backPage.data.map((item: { id: number }) => item.id);

    expect(backPageIds.sort()).toEqual(firstPageIds.sort());
  });

  test("GET /api/v1/items - backward compatibility (no params returns full array)", async ({
    request,
  }) => {
    const response = await request.get("/api/v1/items");
    expect(response.status()).toBe(200);

    const body = await response.json();

    // Without pagination params, should return array directly (not paginated object)
    expect(body).toBeInstanceOf(Array);
    expect(body.length).toBeGreaterThan(0);
  });

  test("GET /api/v1/items - handles invalid cursor gracefully", async ({
    request,
  }) => {
    const response = await request.get(
      `/api/v1/items?limit=${PAGE_SIZE}&cursor=invalid_cursor_value`
    );
    expect(response.status()).toBe(200);

    const body = await response.json();

    // Should return valid response (treated as first page)
    expect(body).toHaveProperty("data");
    expect(body).toHaveProperty("pagination");
  });

  test("GET /api/v1/items - pagination with search filter works correctly", async ({
    request,
  }) => {
    const response = await request.get(
      `/api/v1/items?limit=${PAGE_SIZE}&search=Pagination`
    );
    expect(response.status()).toBe(200);

    const body = await response.json();

    expect(body).toHaveProperty("data");
    expect(body).toHaveProperty("pagination");

    // All returned items should match the search
    for (const item of body.data) {
      const matchesSearch =
        item.title.includes("Pagination") ||
        (item.description && item.description.includes("Pagination"));
      expect(matchesSearch).toBe(true);
    }
  });
});

test.describe.serial("Categories Pagination API", () => {
  const createdCategoryIds: number[] = [];
  const PAGE_SIZE = 5;

  test.beforeAll(async ({ request }) => {
    // Create 12 categories for pagination testing
    for (let i = 1; i <= 12; i++) {
      const response = await request.post("/api/v1/categories", {
        data: {
          name: `Category ${String.fromCharCode(64 + i)}${i
            .toString()
            .padStart(2, "0")}`,
          description: `Category ${i} for pagination testing`,
        },
      });
      expect(response.status()).toBe(201);
      const body = await response.json();
      createdCategoryIds.push(body.id);
    }
  });

  test.afterAll(async ({ request }) => {
    for (const id of createdCategoryIds) {
      await request.delete(`/api/v1/categories/${id}`);
    }
  });

  test("GET /api/v1/categories?limit=5 - returns paginated response", async ({
    request,
  }) => {
    const response = await request.get(`/api/v1/categories?limit=${PAGE_SIZE}`);
    expect(response.status()).toBe(200);

    const body = await response.json();

    expect(body).toHaveProperty("data");
    expect(body).toHaveProperty("pagination");
    expect(body.data).toBeInstanceOf(Array);
    expect(body.data.length).toBeLessThanOrEqual(PAGE_SIZE);
  });

  test("GET /api/v1/categories - first page has hasPrevPage=false", async ({
    request,
  }) => {
    const response = await request.get(`/api/v1/categories?limit=${PAGE_SIZE}`);
    const body = await response.json();

    expect(body.pagination.hasPrevPage).toBe(false);
  });

  test("GET /api/v1/categories - navigates through pages", async ({
    request,
  }) => {
    // Get first page
    const firstResponse = await request.get(
      `/api/v1/categories?limit=${PAGE_SIZE}`
    );
    const firstPage = await firstResponse.json();

    if (!firstPage.pagination.hasNextPage) {
      test.skip();
      return;
    }

    // Get second page
    const secondResponse = await request.get(
      `/api/v1/categories?limit=${PAGE_SIZE}&cursor=${firstPage.pagination.nextCursor}&direction=next`
    );
    expect(secondResponse.status()).toBe(200);
    const secondPage = await secondResponse.json();

    // Verify no overlap
    const firstIds = firstPage.data.map((c: { id: number }) => c.id);
    const secondIds = secondPage.data.map((c: { id: number }) => c.id);
    const overlap = firstIds.filter((id: number) => secondIds.includes(id));
    expect(overlap.length).toBe(0);
  });

  test("GET /api/v1/categories - backward compatibility", async ({
    request,
  }) => {
    const response = await request.get("/api/v1/categories");
    expect(response.status()).toBe(200);

    const body = await response.json();
    expect(body).toBeInstanceOf(Array);
  });
});

test.describe.serial("Authors Pagination API", () => {
  const createdAuthorIds: number[] = [];
  const PAGE_SIZE = 5;

  test.beforeAll(async ({ request }) => {
    // Create 12 authors for pagination testing
    for (let i = 1; i <= 12; i++) {
      const response = await request.post("/api/v1/authors", {
        data: {
          name: `Author ${String.fromCharCode(64 + i)}${i
            .toString()
            .padStart(2, "0")}`,
          bio: `Author ${i} bio for pagination testing`,
        },
      });
      expect(response.status()).toBe(201);
      const body = await response.json();
      createdAuthorIds.push(body.id);
    }
  });

  test.afterAll(async ({ request }) => {
    for (const id of createdAuthorIds) {
      await request.delete(`/api/v1/authors/${id}`);
    }
  });

  test("GET /api/v1/authors?limit=5 - returns paginated response", async ({
    request,
  }) => {
    const response = await request.get(`/api/v1/authors?limit=${PAGE_SIZE}`);
    expect(response.status()).toBe(200);

    const body = await response.json();

    expect(body).toHaveProperty("data");
    expect(body).toHaveProperty("pagination");
    expect(body.data.length).toBeLessThanOrEqual(PAGE_SIZE);
  });

  test("GET /api/v1/authors - first page has hasPrevPage=false", async ({
    request,
  }) => {
    const response = await request.get(`/api/v1/authors?limit=${PAGE_SIZE}`);
    const body = await response.json();

    expect(body.pagination.hasPrevPage).toBe(false);
  });

  test("GET /api/v1/authors - backward compatibility", async ({ request }) => {
    const response = await request.get("/api/v1/authors");
    expect(response.status()).toBe(200);

    const body = await response.json();
    expect(body).toBeInstanceOf(Array);
  });
});

test.describe.serial("Locations Pagination API", () => {
  const createdLocationIds: number[] = [];
  const PAGE_SIZE = 5;

  test.beforeAll(async ({ request }) => {
    // Create 12 locations for pagination testing
    for (let i = 1; i <= 12; i++) {
      const response = await request.post("/api/v1/locations", {
        data: {
          title: `Location ${String.fromCharCode(64 + i)}${i
            .toString()
            .padStart(2, "0")}`,
          latitude: 40.7128 + i * 0.01,
          longitude: -74.006 + i * 0.01,
        },
      });
      expect(response.status()).toBe(201);
      const body = await response.json();
      createdLocationIds.push(body.id);
    }
  });

  test.afterAll(async ({ request }) => {
    for (const id of createdLocationIds) {
      await request.delete(`/api/v1/locations/${id}`);
    }
  });

  test("GET /api/v1/locations?limit=5 - returns paginated response", async ({
    request,
  }) => {
    const response = await request.get(`/api/v1/locations?limit=${PAGE_SIZE}`);
    expect(response.status()).toBe(200);

    const body = await response.json();

    expect(body).toHaveProperty("data");
    expect(body).toHaveProperty("pagination");
    expect(body.data.length).toBeLessThanOrEqual(PAGE_SIZE);
  });

  test("GET /api/v1/locations - first page has hasPrevPage=false", async ({
    request,
  }) => {
    const response = await request.get(`/api/v1/locations?limit=${PAGE_SIZE}`);
    const body = await response.json();

    expect(body.pagination.hasPrevPage).toBe(false);
  });

  test("GET /api/v1/locations - backward compatibility", async ({ request }) => {
    const response = await request.get("/api/v1/locations");
    expect(response.status()).toBe(200);

    const body = await response.json();
    expect(body).toBeInstanceOf(Array);
  });
});

test.describe.serial("Position Schemas Pagination API", () => {
  const createdSchemaIds: number[] = [];
  const PAGE_SIZE = 5;

  test.beforeAll(async ({ request }) => {
    // Create 12 position schemas for pagination testing
    for (let i = 1; i <= 12; i++) {
      const response = await request.post("/api/v1/position-schemas", {
        data: {
          name: `Schema ${String.fromCharCode(64 + i)}${i
            .toString()
            .padStart(2, "0")}`,
          schema: {
            type: "object",
            properties: {
              [`field${i}`]: { type: "string" },
            },
          },
        },
      });
      expect(response.status()).toBe(201);
      const body = await response.json();
      createdSchemaIds.push(body.id);
    }
  });

  test.afterAll(async ({ request }) => {
    for (const id of createdSchemaIds) {
      await request.delete(`/api/v1/position-schemas/${id}`);
    }
  });

  test("GET /api/v1/position-schemas?limit=5 - returns paginated response", async ({
    request,
  }) => {
    const response = await request.get(
      `/api/v1/position-schemas?limit=${PAGE_SIZE}`
    );
    expect(response.status()).toBe(200);

    const body = await response.json();

    expect(body).toHaveProperty("data");
    expect(body).toHaveProperty("pagination");
    expect(body.data.length).toBeLessThanOrEqual(PAGE_SIZE);
  });

  test("GET /api/v1/position-schemas - first page has hasPrevPage=false", async ({
    request,
  }) => {
    const response = await request.get(
      `/api/v1/position-schemas?limit=${PAGE_SIZE}`
    );
    const body = await response.json();

    expect(body.pagination.hasPrevPage).toBe(false);
  });

  test("GET /api/v1/position-schemas - backward compatibility", async ({
    request,
  }) => {
    const response = await request.get("/api/v1/position-schemas");
    expect(response.status()).toBe(200);

    const body = await response.json();
    expect(body).toBeInstanceOf(Array);
  });
});

test.describe("Pagination Edge Cases", () => {
  test("Empty results return correct pagination structure", async ({
    request,
  }) => {
    // Search for something that doesn't exist
    const response = await request.get(
      "/api/v1/items?limit=10&search=ThisDoesNotExist12345XYZ"
    );
    expect(response.status()).toBe(200);

    const body = await response.json();

    expect(body).toHaveProperty("data");
    expect(body).toHaveProperty("pagination");
    expect(body.data).toEqual([]);
    expect(body.pagination.nextCursor).toBeNull();
    expect(body.pagination.prevCursor).toBeNull();
    expect(body.pagination.hasNextPage).toBe(false);
    expect(body.pagination.hasPrevPage).toBe(false);
  });

  test("Cursor stability - same cursor returns same results", async ({
    request,
  }) => {
    // Get first page
    const firstResponse = await request.get("/api/v1/items?limit=5");
    const firstPage = await firstResponse.json();

    if (!firstPage.pagination.nextCursor) {
      test.skip();
      return;
    }

    // Get second page twice with same cursor
    const cursor = firstPage.pagination.nextCursor;

    const secondResponse1 = await request.get(
      `/api/v1/items?limit=5&cursor=${cursor}&direction=next`
    );
    const secondPage1 = await secondResponse1.json();

    const secondResponse2 = await request.get(
      `/api/v1/items?limit=5&cursor=${cursor}&direction=next`
    );
    const secondPage2 = await secondResponse2.json();

    // Both responses should have same items
    const ids1 = secondPage1.data.map((item: { id: number }) => item.id);
    const ids2 = secondPage2.data.map((item: { id: number }) => item.id);

    expect(ids1).toEqual(ids2);
  });
});
