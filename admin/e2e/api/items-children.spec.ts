import { test, expect } from "@playwright/test";

test.describe.serial("Items API - Children in Detail Response", () => {
  let parentId: string;
  let childId: string;
  let otherUserParentId: string;
  let otherUserChildId: string;

  test("Setup - create parent and child items", async ({ request }) => {
    // Create parent item
    const parentResponse = await request.post("/api/v1/items", {
      data: { title: "Parent Item", visibility: "privateAccess" },
    });
    expect(parentResponse.status()).toBe(201);
    parentId = (await parentResponse.json()).id;

    // Create child item with parentId
    const childResponse = await request.post("/api/v1/items", {
      data: {
        title: "Child Item",
        parentId,
        visibility: "privateAccess",
      },
    });
    expect(childResponse.status()).toBe(201);
    childId = (await childResponse.json()).id;
  });

  test("GET /api/v1/items/{parentId} - should include child in children array", async ({
    request,
  }) => {
    const response = await request.get(`/api/v1/items/${parentId}`);
    expect(response.status()).toBe(200);
    const body = await response.json();

    expect(body.children).toHaveLength(1);
    expect(body.children[0].id).toBe(childId);
    expect(body.children[0].title).toBe("Child Item");
  });

  test("GET /api/v1/items/{childId} - should have parentId set", async ({
    request,
  }) => {
    const response = await request.get(`/api/v1/items/${childId}`);
    expect(response.status()).toBe(200);
    const body = await response.json();

    expect(body.parentId).toBe(parentId);
    expect(body.children).toHaveLength(0);
  });

  test("Public parent should still show children in detail", async ({
    request,
  }) => {
    // Make parent public
    await request.put(`/api/v1/items/${parentId}`, {
      data: { title: "Parent Item", visibility: "publicAccess" },
    });

    const response = await request.get(`/api/v1/items/${parentId}`);
    expect(response.status()).toBe(200);
    const body = await response.json();

    // Children should still be returned (they belong to the same user)
    expect(body.children).toHaveLength(1);
    expect(body.children[0].id).toBe(childId);
  });

  test("PUT /api/v1/items/{childId}/parent - add child via setParent", async ({
    request,
  }) => {
    // Create another item to add as child
    const newChildResponse = await request.post("/api/v1/items", {
      data: { title: "New Child", visibility: "privateAccess" },
    });
    expect(newChildResponse.status()).toBe(201);
    const newChildId = (await newChildResponse.json()).id;

    // Set parent via dedicated endpoint
    const setParentResponse = await request.put(
      `/api/v1/items/${newChildId}/parent`,
      { data: { parentId } },
    );
    expect(setParentResponse.status()).toBe(200);

    // Verify parent now has 2 children
    const parentResponse = await request.get(`/api/v1/items/${parentId}`);
    expect(parentResponse.status()).toBe(200);
    const body = await parentResponse.json();

    expect(body.children).toHaveLength(2);
    const childIds = body.children.map((c: { id: string }) => c.id);
    expect(childIds).toContain(childId);
    expect(childIds).toContain(newChildId);

    // Cleanup extra child
    await request.delete(`/api/v1/items/${newChildId}`);
  });

  test("GET /api/v1/items?parentId=null - should only return root items", async ({
    request,
  }) => {
    const response = await request.get("/api/v1/items?parentId=null");
    expect(response.status()).toBe(200);
    const body = await response.json();

    // Child item should NOT appear (it has a parent)
    const ids = body.data.map((item: { id: string }) => item.id);
    expect(ids).toContain(parentId);
    expect(ids).not.toContain(childId);
  });

  test("Other user cannot add items from a different user as children", async ({
    request,
  }) => {
    // Create items as other user
    const otherParentResponse = await request.post("/api/v1/items", {
      headers: { "X-Test-User-Id": "other-user" },
      data: { title: "Other Parent", visibility: "privateAccess" },
    });
    expect(otherParentResponse.status()).toBe(201);
    otherUserParentId = (await otherParentResponse.json()).id;

    // Try to set first user's child as other user's child
    const setParentResponse = await request.put(
      `/api/v1/items/${childId}/parent`,
      {
        headers: { "X-Test-User-Id": "other-user" },
        data: { parentId: otherUserParentId },
      },
    );
    // Should fail - childId belongs to default test user, not "other-user"
    expect(setParentResponse.status()).toBe(403);
  });

  test("User cannot add another user's public item as child via setParent", async ({
    request,
  }) => {
    // Make first user's parent public
    await request.put(`/api/v1/items/${parentId}`, {
      data: { title: "Parent Item", visibility: "publicAccess" },
    });

    // Other user tries to set first user's public item as child of their parent
    const setParentResponse = await request.put(
      `/api/v1/items/${parentId}/parent`,
      {
        headers: { "X-Test-User-Id": "other-user" },
        data: { parentId: otherUserParentId },
      },
    );
    // Should fail - parentId (first user's item) doesn't belong to other-user
    expect(setParentResponse.status()).toBe(403);

    // Revert visibility
    await request.put(`/api/v1/items/${parentId}`, {
      data: { title: "Parent Item", visibility: "privateAccess" },
    });
  });

  test("User cannot add another user's private item as child via setParent", async ({
    request,
  }) => {
    // Other user tries to set first user's private item as child of their parent
    const setParentResponse = await request.put(
      `/api/v1/items/${childId}/parent`,
      {
        headers: { "X-Test-User-Id": "other-user" },
        data: { parentId: otherUserParentId },
      },
    );
    // Should fail - childId belongs to default test user, not "other-user"
    expect(setParentResponse.status()).toBe(403);
  });

  test("User cannot create item with another user's item as parent", async ({
    request,
  }) => {
    // Other user tries to create an item with first user's item as parent
    const response = await request.post("/api/v1/items", {
      headers: { "X-Test-User-Id": "other-user" },
      data: {
        title: "Cross-user Child",
        parentId: parentId,
        visibility: "privateAccess",
      },
    });
    // Should fail - parentId belongs to default test user, not "other-user"
    expect(response.status()).toBe(400);
  });

  test("Other user's parent detail should not show first user's children", async ({
    request,
  }) => {
    // Create a child for other user
    const otherChildResponse = await request.post("/api/v1/items", {
      headers: { "X-Test-User-Id": "other-user" },
      data: {
        title: "Other Child",
        parentId: otherUserParentId,
        visibility: "privateAccess",
      },
    });
    expect(otherChildResponse.status()).toBe(201);
    otherUserChildId = (await otherChildResponse.json()).id;

    // Fetch other user's parent - should only show their own child
    const response = await request.get(`/api/v1/items/${otherUserParentId}`, {
      headers: { "X-Test-User-Id": "other-user" },
    });
    expect(response.status()).toBe(200);
    const body = await response.json();

    expect(body.children).toHaveLength(1);
    expect(body.children[0].id).toBe(otherUserChildId);
    // Should NOT contain first user's child
    const childIds = body.children.map((c: { id: string }) => c.id);
    expect(childIds).not.toContain(childId);
  });

  test("Cleanup", async ({ request }) => {
    await request.delete(`/api/v1/items/${childId}`);
    await request.delete(`/api/v1/items/${parentId}`);
    await request.delete(`/api/v1/items/${otherUserChildId}`, {
      headers: { "X-Test-User-Id": "other-user" },
    });
    await request.delete(`/api/v1/items/${otherUserParentId}`, {
      headers: { "X-Test-User-Id": "other-user" },
    });
  });
});
