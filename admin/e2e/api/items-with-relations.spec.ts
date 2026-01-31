import { test, expect } from "@playwright/test";

test.describe.serial("Items API with Relations", () => {
  let categoryId: number;
  let locationId: number;
  let authorId: number;
  let parentItemId: number;
  let childItemId: number;

  test("Setup - create related entities", async ({ request }) => {
    // Create category
    const categoryResponse = await request.post("/api/v1/categories", {
      data: { name: "Electronics", description: "Electronic devices" },
    });
    const categoryBody = await categoryResponse.json();
    categoryId = categoryBody.id;

    // Create location
    const locationResponse = await request.post("/api/v1/locations", {
      data: { title: "Warehouse A", latitude: 37.7749, longitude: -122.4194 },
    });
    const locationBody = await locationResponse.json();
    locationId = locationBody.id;

    // Create author
    const authorResponse = await request.post("/api/v1/authors", {
      data: { name: "John Doe", bio: "Storage manager" },
    });
    const authorBody = await authorResponse.json();
    authorId = authorBody.id;
  });

  test("POST /api/v1/items - should create item with all relations", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/items", {
      data: {
        title: "Laptop with Relations",
        description: "A laptop with category, location, and author",
        categoryId,
        locationId,
        authorId,
        price: 999.99,
        visibility: "public",
      },
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body.title).toBe("Laptop with Relations");
    expect(body.categoryId).toBe(categoryId);
    expect(body.locationId).toBe(locationId);
    expect(body.authorId).toBe(authorId);
    expect(body.price).toBe(999.99);

    parentItemId = body.id;
  });

  test("GET /api/v1/items/{id} - should return item with relation details", async ({
    request,
  }) => {
    const response = await request.get(`/api/v1/items/${parentItemId}`);

    expect(response.status()).toBe(200);
    const body = await response.json();

    // Check that relations are populated
    expect(body.category).toHaveProperty("id", categoryId);
    expect(body.category).toHaveProperty("name", "Electronics");
    expect(body.location).toHaveProperty("id", locationId);
    expect(body.location).toHaveProperty("title", "Warehouse A");
    expect(body.author).toHaveProperty("id", authorId);
    expect(body.author).toHaveProperty("name", "John Doe");
  });

  test("GET /api/v1/items?categoryId={id} - should filter by category", async ({
    request,
  }) => {
    const response = await request.get(
      `/api/v1/items?categoryId=${categoryId}`,
    );

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body).toBeInstanceOf(Array);
    expect(
      body.every((item: any) => item.categoryId === categoryId),
    ).toBeTruthy();
  });

  test("GET /api/v1/items?locationId={id} - should filter by location", async ({
    request,
  }) => {
    const response = await request.get(
      `/api/v1/items?locationId=${locationId}`,
    );

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body).toBeInstanceOf(Array);
    expect(
      body.every((item: any) => item.locationId === locationId),
    ).toBeTruthy();
  });

  test("GET /api/v1/items?authorId={id} - should filter by author", async ({
    request,
  }) => {
    const response = await request.get(`/api/v1/items?authorId=${authorId}`);

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body).toBeInstanceOf(Array);
    expect(body.every((item: any) => item.authorId === authorId)).toBeTruthy();
  });

  test("POST /api/v1/items - should create child item with parent", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/items", {
      data: {
        title: "Laptop Charger",
        description: "Charger for the laptop",
        parentId: parentItemId,
        categoryId,
        visibility: "public",
      },
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body.parentId).toBe(parentItemId);

    childItemId = body.id;
  });

  test("GET /api/v1/items?visibility=public - should filter by visibility", async ({
    request,
  }) => {
    const response = await request.get("/api/v1/items?visibility=public");

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body).toBeInstanceOf(Array);
    expect(
      body.every((item: any) => item.visibility === "public"),
    ).toBeTruthy();
  });

  test("Cleanup - delete test data", async ({ request }) => {
    // Delete items
    await request.delete(`/api/v1/items/${childItemId}`);
    await request.delete(`/api/v1/items/${parentItemId}`);

    // Delete relations
    await request.delete(`/api/v1/categories/${categoryId}`);
    await request.delete(`/api/v1/locations/${locationId}`);
    await request.delete(`/api/v1/authors/${authorId}`);
  });
});
