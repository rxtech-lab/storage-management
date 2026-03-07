import { test, expect } from "@playwright/test";
import { PaginatedItemsResponse } from "@/lib/schemas/items";

test.describe.serial("Items API - sortBy lastUsedAsParent", () => {
  let itemAId: string;
  let itemBId: string;
  let itemCId: string;
  let child1Id: string;
  let child2Id: string;

  test("Setup - create 3 parent items", async ({ request }) => {
    // Create items A, B, C with slight delay between to ensure different createdAt
    const responseA = await request.post("/api/v1/items", {
      data: { title: "Parent A", visibility: "privateAccess" },
    });
    expect(responseA.status()).toBe(201);
    itemAId = (await responseA.json()).id;

    const responseB = await request.post("/api/v1/items", {
      data: { title: "Parent B", visibility: "privateAccess" },
    });
    expect(responseB.status()).toBe(201);
    itemBId = (await responseB.json()).id;

    const responseC = await request.post("/api/v1/items", {
      data: { title: "Parent C", visibility: "privateAccess" },
    });
    expect(responseC.status()).toBe(201);
    itemCId = (await responseC.json()).id;
  });

  test("Create children to trigger lastUsedAsParent - B first, then A", async ({
    request,
  }) => {
    // Create child1 with parent B (B gets lastUsedAsParent timestamp first)
    const child1Response = await request.post("/api/v1/items", {
      data: {
        title: "Child of B",
        parentId: itemBId,
        visibility: "privateAccess",
      },
    });
    expect(child1Response.status()).toBe(201);
    child1Id = (await child1Response.json()).id;

    // Delay >1s to ensure different timestamps (SQLite stores seconds, not ms)
    await new Promise((resolve) => setTimeout(resolve, 1100));

    // Create child2 with parent A (A gets lastUsedAsParent timestamp second, more recent)
    const child2Response = await request.post("/api/v1/items", {
      data: {
        title: "Child of A",
        parentId: itemAId,
        visibility: "privateAccess",
      },
    });
    expect(child2Response.status()).toBe(201);
    child2Id = (await child2Response.json()).id;
  });

  test("GET /api/v1/items?sortBy=lastUsedAsParent - A before B, both before C", async ({
    request,
  }) => {
    const response = await request.get(
      "/api/v1/items?sortBy=lastUsedAsParent",
    );
    expect(response.status()).toBe(200);
    const body = await response.json();
    const validated = PaginatedItemsResponse.parse(body);

    const ids = validated.data.map((item) => item.id);
    const indexA = ids.indexOf(itemAId);
    const indexB = ids.indexOf(itemBId);
    const indexC = ids.indexOf(itemCId);

    // A was used as parent more recently than B
    expect(indexA).toBeLessThan(indexB);
    // Both A and B were used as parents, C was never used
    expect(indexB).toBeLessThan(indexC);
  });

  test("PUT /api/v1/items/{id}/parent - setItemParent updates lastUsedAsParent", async ({
    request,
  }) => {
    // Set child1's parent to C via setItemParent API
    const response = await request.put(`/api/v1/items/${child1Id}/parent`, {
      data: { parentId: itemCId },
    });
    expect(response.status()).toBe(200);

    // Now C should be the most recently used parent
    const listResponse = await request.get(
      "/api/v1/items?sortBy=lastUsedAsParent",
    );
    expect(listResponse.status()).toBe(200);
    const body = await listResponse.json();
    const validated = PaginatedItemsResponse.parse(body);

    const ids = validated.data.map((item) => item.id);
    const indexA = ids.indexOf(itemAId);
    const indexC = ids.indexOf(itemCId);

    // C was used as parent most recently (via setItemParent)
    expect(indexC).toBeLessThan(indexA);
  });

  test("GET /api/v1/items - default sort is still createdAt DESC", async ({
    request,
  }) => {
    const response = await request.get("/api/v1/items");
    expect(response.status()).toBe(200);
    const body = await response.json();
    const validated = PaginatedItemsResponse.parse(body);

    // Items should be sorted by createdAt DESC (newest first)
    for (let i = 0; i < validated.data.length - 1; i++) {
      const current = new Date(validated.data[i].createdAt).getTime();
      const next = new Date(validated.data[i + 1].createdAt).getTime();
      expect(current).toBeGreaterThanOrEqual(next);
    }
  });

  test("Cleanup - delete test items", async ({ request }) => {
    // Delete children first (they reference parents)
    await request.delete(`/api/v1/items/${child1Id}`);
    await request.delete(`/api/v1/items/${child2Id}`);
    await request.delete(`/api/v1/items/${itemAId}`);
    await request.delete(`/api/v1/items/${itemBId}`);
    await request.delete(`/api/v1/items/${itemCId}`);
  });
});
