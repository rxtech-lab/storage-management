import { test, expect } from "@playwright/test";
import { PaginatedItemsResponse } from "@/lib/schemas/items";

test.describe.serial(
  "Items API - Filter by Tags and Date Fields",
  () => {
    const USER_ID = `filter-test-user-${crypto.randomUUID()}`;
    const headers = { "X-Test-User-Id": USER_ID };

    let tagA: string;
    let tagB: string;
    let tagC: string;
    let itemEarly: string; // itemDate=2024-01-01, expiresAt=2024-06-01, tags: A
    let itemMiddle: string; // itemDate=2024-06-15, expiresAt=2024-12-01, tags: A, B
    let itemLate: string; // itemDate=2025-01-01, expiresAt=2025-06-01, tags: B
    let itemNoDate: string; // no dates, tags: C

    // --- Setup: create tags ---
    test("setup - create tags", async ({ request }) => {
      const resA = await request.post("/api/v1/tags", {
        headers,
        data: { title: "TagA", color: "#ff0000" },
      });
      expect(resA.status()).toBe(201);
      tagA = (await resA.json()).id;

      const resB = await request.post("/api/v1/tags", {
        headers,
        data: { title: "TagB", color: "#00ff00" },
      });
      expect(resB.status()).toBe(201);
      tagB = (await resB.json()).id;

      const resC = await request.post("/api/v1/tags", {
        headers,
        data: { title: "TagC", color: "#0000ff" },
      });
      expect(resC.status()).toBe(201);
      tagC = (await resC.json()).id;
    });

    // --- Setup: create items ---
    test("setup - create items with dates", async ({ request }) => {
      const res1 = await request.post("/api/v1/items", {
        headers,
        data: {
          title: "Early Item",
          visibility: "privateAccess",
          itemDate: "2024-01-01T00:00:00.000Z",
          expiresAt: "2024-06-01T00:00:00.000Z",
        },
      });
      expect(res1.status()).toBe(201);
      itemEarly = (await res1.json()).id;

      const res2 = await request.post("/api/v1/items", {
        headers,
        data: {
          title: "Middle Item",
          visibility: "privateAccess",
          itemDate: "2024-06-15T00:00:00.000Z",
          expiresAt: "2024-12-01T00:00:00.000Z",
        },
      });
      expect(res2.status()).toBe(201);
      itemMiddle = (await res2.json()).id;

      const res3 = await request.post("/api/v1/items", {
        headers,
        data: {
          title: "Late Item",
          visibility: "privateAccess",
          itemDate: "2025-01-01T00:00:00.000Z",
          expiresAt: "2025-06-01T00:00:00.000Z",
        },
      });
      expect(res3.status()).toBe(201);
      itemLate = (await res3.json()).id;

      const res4 = await request.post("/api/v1/items", {
        headers,
        data: {
          title: "No Date Item",
          visibility: "privateAccess",
        },
      });
      expect(res4.status()).toBe(201);
      itemNoDate = (await res4.json()).id;
    });

    // --- Setup: assign tags ---
    test("setup - assign tags to items", async ({ request }) => {
      // itemEarly: TagA
      await request.post(`/api/v1/items/${itemEarly}/tags`, {
        headers,
        data: { tagId: tagA },
      });
      // itemMiddle: TagA, TagB
      await request.post(`/api/v1/items/${itemMiddle}/tags`, {
        headers,
        data: { tagId: tagA },
      });
      await request.post(`/api/v1/items/${itemMiddle}/tags`, {
        headers,
        data: { tagId: tagB },
      });
      // itemLate: TagB
      await request.post(`/api/v1/items/${itemLate}/tags`, {
        headers,
        data: { tagId: tagB },
      });
      // itemNoDate: TagC
      await request.post(`/api/v1/items/${itemNoDate}/tags`, {
        headers,
        data: { tagId: tagC },
      });
    });

    // --- Tag filter tests ---
    test("filter by single tag - TagA returns Early and Middle", async ({
      request,
    }) => {
      const response = await request.get(
        `/api/v1/items?tagIds=${tagA}`,
        { headers }
      );
      expect(response.status()).toBe(200);
      const body = PaginatedItemsResponse.parse(await response.json());
      const ids = body.data.map((i) => i.id);
      expect(ids).toContain(itemEarly);
      expect(ids).toContain(itemMiddle);
      expect(ids).not.toContain(itemLate);
      expect(ids).not.toContain(itemNoDate);
    });

    test("filter by multiple tags AND - TagA+TagB returns only Middle", async ({
      request,
    }) => {
      const response = await request.get(
        `/api/v1/items?tagIds=${tagA},${tagB}`,
        { headers }
      );
      expect(response.status()).toBe(200);
      const body = PaginatedItemsResponse.parse(await response.json());
      const ids = body.data.map((i) => i.id);
      expect(ids).toContain(itemMiddle);
      expect(ids).not.toContain(itemEarly);
      expect(ids).not.toContain(itemLate);
    });

    test("filter by non-existent tag returns empty", async ({ request }) => {
      const response = await request.get(
        `/api/v1/items?tagIds=nonexistent-tag-id`,
        { headers }
      );
      expect(response.status()).toBe(200);
      const body = PaginatedItemsResponse.parse(await response.json());
      expect(body.data).toHaveLength(0);
    });

    // --- Item date filter tests ---
    test("itemDateOp=gt returns items with itemDate after 2024-06-15", async ({
      request,
    }) => {
      const response = await request.get(
        `/api/v1/items?itemDateOp=gt&itemDateValue=2024-06-15T00:00:00.000Z`,
        { headers }
      );
      expect(response.status()).toBe(200);
      const body = PaginatedItemsResponse.parse(await response.json());
      const ids = body.data.map((i) => i.id);
      expect(ids).toContain(itemLate);
      expect(ids).not.toContain(itemEarly);
      expect(ids).not.toContain(itemMiddle);
    });

    test("itemDateOp=lte returns items with itemDate on or before 2024-06-15", async ({
      request,
    }) => {
      const response = await request.get(
        `/api/v1/items?itemDateOp=lte&itemDateValue=2024-06-15T00:00:00.000Z`,
        { headers }
      );
      expect(response.status()).toBe(200);
      const body = PaginatedItemsResponse.parse(await response.json());
      const ids = body.data.map((i) => i.id);
      expect(ids).toContain(itemEarly);
      expect(ids).toContain(itemMiddle);
      expect(ids).not.toContain(itemLate);
    });

    test("itemDateOp=eq returns exact match", async ({ request }) => {
      const response = await request.get(
        `/api/v1/items?itemDateOp=eq&itemDateValue=2024-01-01T00:00:00.000Z`,
        { headers }
      );
      expect(response.status()).toBe(200);
      const body = PaginatedItemsResponse.parse(await response.json());
      const ids = body.data.map((i) => i.id);
      expect(ids).toContain(itemEarly);
      expect(ids).not.toContain(itemMiddle);
      expect(ids).not.toContain(itemLate);
    });

    // --- Deadline filter tests ---
    test("expiresAtOp=lt returns items expiring before 2025-01-01", async ({
      request,
    }) => {
      const response = await request.get(
        `/api/v1/items?expiresAtOp=lt&expiresAtValue=2025-01-01T00:00:00.000Z`,
        { headers }
      );
      expect(response.status()).toBe(200);
      const body = PaginatedItemsResponse.parse(await response.json());
      const ids = body.data.map((i) => i.id);
      expect(ids).toContain(itemEarly);
      expect(ids).toContain(itemMiddle);
      expect(ids).not.toContain(itemLate);
    });

    test("expiresAtOp=gte returns items expiring on or after 2025-01-01", async ({
      request,
    }) => {
      const response = await request.get(
        `/api/v1/items?expiresAtOp=gte&expiresAtValue=2025-01-01T00:00:00.000Z`,
        { headers }
      );
      expect(response.status()).toBe(200);
      const body = PaginatedItemsResponse.parse(await response.json());
      const ids = body.data.map((i) => i.id);
      expect(ids).toContain(itemLate);
      expect(ids).not.toContain(itemEarly);
      expect(ids).not.toContain(itemMiddle);
    });

    // --- Combined filter test ---
    test("combined: tagIds + itemDate filter", async ({ request }) => {
      // TagA items (Early, Middle) + itemDate >= 2024-06-15 => Middle only
      const response = await request.get(
        `/api/v1/items?tagIds=${tagA}&itemDateOp=gte&itemDateValue=2024-06-15T00:00:00.000Z`,
        { headers }
      );
      expect(response.status()).toBe(200);
      const body = PaginatedItemsResponse.parse(await response.json());
      const ids = body.data.map((i) => i.id);
      expect(ids).toContain(itemMiddle);
      expect(ids).not.toContain(itemEarly);
      expect(ids).not.toContain(itemLate);
    });

    // --- Cleanup ---
    test("cleanup - delete items and tags", async ({ request }) => {
      for (const id of [itemEarly, itemMiddle, itemLate, itemNoDate]) {
        await request.delete(`/api/v1/items/${id}`, { headers });
      }
      for (const id of [tagA, tagB, tagC]) {
        await request.delete(`/api/v1/tags/${id}`, { headers });
      }
    });
  }
);
