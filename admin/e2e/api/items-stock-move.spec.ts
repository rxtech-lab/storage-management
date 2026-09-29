import { test, expect, type APIRequestContext } from "@playwright/test";

test.describe.serial("Items API - Stock placements and moves", () => {
  const USER_ID = `stock-move-user-${crypto.randomUUID()}`;
  const OTHER_USER_ID = `stock-move-other-${crypto.randomUUID()}`;
  const headers = { "X-Test-User-Id": USER_ID };
  let boxA: string;
  let boxB: string;
  let itemId: string;
  let stockId: string;

  async function createItem(request: APIRequestContext, title: string, parentId?: string) {
    const response = await request.post("/api/v1/items", {
      headers,
      data: { title, parentId, visibility: "privateAccess" },
    });
    expect(response.status()).toBe(201);
    return (await response.json()).id as string;
  }

  async function getDetail(request: APIRequestContext, id: string) {
    const response = await request.get(`/api/v1/items/${id}`, { headers });
    expect(response.status()).toBe(200);
    return response.json();
  }

  async function move(request: APIRequestContext, data: Record<string, unknown>, h = headers) {
    return request.post(`/api/v1/items/${itemId}/stock-move`, { headers: h, data });
  }

  test("Setup - boxes and an item with 5 units in box A", async ({ request }) => {
    boxA = await createItem(request, "Box A");
    boxB = await createItem(request, "Box B");
    itemId = await createItem(request, "Screws", boxA);

    const stock = await request.post(`/api/v1/items/${itemId}/stock-history`, {
      headers,
      data: { quantity: 5 },
    });
    expect(stock.status()).toBe(201);

    const detail = await getDetail(request, itemId);
    expect(detail.quantity).toBe(5);
    expect(detail.mainQuantity).toBe(5);
    expect(detail.stocks).toHaveLength(0);
    expect(detail.parent).toEqual({ id: boxA, title: "Box A" });
  });

  test("Partial move splits units into a placement under the destination", async ({
    request,
  }) => {
    const response = await move(request, { toParentId: boxB, quantity: 2 });
    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.quantity).toBe(2);
    expect(body.stockId).toBeTruthy();
    stockId = body.stockId;

    const detail = await getDetail(request, itemId);
    expect(detail.quantity).toBe(5);
    expect(detail.mainQuantity).toBe(3);
    expect(detail.parentId).toBe(boxA);
    expect(detail.stocks).toHaveLength(1);
    expect(detail.stocks[0]).toMatchObject({
      id: stockId,
      parentId: boxB,
      parent: { id: boxB, title: "Box B" },
      quantity: 2,
    });

    const notes = detail.stockHistory.map((h: { note: string }) => h.note);
    expect(notes).toContain("Moved to Box B");
    expect(notes).toContain("Moved from Box A");

    const box = await getDetail(request, boxB);
    expect(box.storedStocks).toHaveLength(1);
    expect(box.storedStocks[0].item.id).toBe(itemId);
    expect(box.storedStocks[0].stock.quantity).toBe(2);
  });

  test("Another partial move to the same parent merges into the placement", async ({
    request,
  }) => {
    const response = await move(request, { toParentId: boxB, quantity: 1 });
    expect(response.status()).toBe(200);
    expect((await response.json()).stockId).toBe(stockId);

    const detail = await getDetail(request, itemId);
    expect(detail.mainQuantity).toBe(2);
    expect(detail.stocks).toHaveLength(1);
    expect(detail.stocks[0].quantity).toBe(3);
  });

  test("PUT /api/v1/stocks/{id} updates the placement note", async ({ request }) => {
    const response = await request.put(`/api/v1/stocks/${stockId}`, {
      headers,
      data: { note: "Top shelf" },
    });
    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.note).toBe("Top shelf");
    expect(body.quantity).toBe(3);
  });

  test("Stock history entries can target a placement", async ({ request }) => {
    const response = await request.post(`/api/v1/items/${itemId}/stock-history`, {
      headers,
      data: { quantity: -1, stockId },
    });
    expect(response.status()).toBe(201);
    expect((await response.json()).stockId).toBe(stockId);

    const detail = await getDetail(request, itemId);
    expect(detail.quantity).toBe(4);
    expect(detail.stocks[0].quantity).toBe(2);
    expect(detail.mainQuantity).toBe(2);
  });

  test("Moving a whole placement to the main parent folds it back", async ({ request }) => {
    const response = await move(request, { fromStockId: stockId, toParentId: boxA });
    expect(response.status()).toBe(200);
    expect((await response.json()).stockId).toBeNull();

    const detail = await getDetail(request, itemId);
    expect(detail.stocks).toHaveLength(0);
    expect(detail.mainQuantity).toBe(4);
    expect(detail.quantity).toBe(4);
  });

  test("Split with merge=false creates a new placement in the same parent", async ({
    request,
  }) => {
    const response = await move(request, { toParentId: boxA, quantity: 1, merge: false });
    expect(response.status()).toBe(200);
    stockId = (await response.json()).stockId;

    const detail = await getDetail(request, itemId);
    expect(detail.stocks).toHaveLength(1);
    expect(detail.stocks[0].parentId).toBe(boxA);
    expect(detail.stocks[0].quantity).toBe(1);
    expect(detail.mainQuantity).toBe(3);
  });

  test("DELETE /api/v1/stocks/{id} returns units to the main placement", async ({
    request,
  }) => {
    const response = await request.delete(`/api/v1/stocks/${stockId}`, { headers });
    expect(response.status()).toBe(200);

    const detail = await getDetail(request, itemId);
    expect(detail.stocks).toHaveLength(0);
    expect(detail.mainQuantity).toBe(4);
  });

  test("Whole move of the main placement re-parents the item", async ({ request }) => {
    const response = await move(request, { toParentId: boxB });
    expect(response.status()).toBe(200);
    expect((await response.json()).quantity).toBe(4);

    const detail = await getDetail(request, itemId);
    expect(detail.parentId).toBe(boxB);
    expect(detail.mainQuantity).toBe(4);
  });

  test("Omitting toParentId moves to no parent", async ({ request }) => {
    const response = await move(request, { quantity: 1 });
    expect(response.status()).toBe(200);

    const detail = await getDetail(request, itemId);
    expect(detail.parentId).toBe(boxB);
    expect(detail.mainQuantity).toBe(3);
    expect(detail.stocks).toHaveLength(1);
    expect(detail.stocks[0].parentId).toBeNull();
    expect(detail.stocks[0].quantity).toBe(1);
  });

  test("Moving an item into itself is rejected", async ({ request }) => {
    const response = await move(request, { toParentId: itemId });
    expect(response.status()).toBe(400);
  });

  test("Other users can't move the item", async ({ request }) => {
    const response = await move(
      request,
      { toParentId: null },
      { "X-Test-User-Id": OTHER_USER_ID },
    );
    expect(response.status()).toBe(403);
  });
});
