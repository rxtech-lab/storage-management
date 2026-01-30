import { test, expect } from "@playwright/test";

test.describe.serial("File Upload API", () => {
  let fileId: number;
  let itemId: number;

  test("POST /api/v1/upload/presigned - should return upload URL and file ID", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/upload/presigned", {
      data: {
        filename: "test-image.jpg",
        contentType: "image/jpeg",
        size: 1024,
      },
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body).toHaveProperty("fileId");
    expect(body).toHaveProperty("uploadUrl");
    expect(body).toHaveProperty("key");
    expect(body).toHaveProperty("expiresAt");
    expect(body.uploadUrl).toContain("mock-s3.example.com");
    expect(body.key).toContain("mock/");

    fileId = body.fileId;
  });

  test("POST /api/v1/upload/presigned - should reject non-image content types", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/upload/presigned", {
      data: {
        filename: "test-file.pdf",
        contentType: "application/pdf",
        size: 1024,
      },
    });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body.error).toContain("image");
  });

  test("POST /api/v1/upload/presigned - should validate required fields", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/upload/presigned", {
      data: {
        filename: "test.jpg",
        // missing contentType
      },
    });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body).toHaveProperty("error");
  });

  test("POST /api/v1/items - should create item with file IDs and return signed URLs", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/items", {
      data: {
        title: "Item with Image",
        description: "Test item with uploaded image",
        visibility: "public",
        images: [`file:${fileId}`],
      },
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body).toHaveProperty("id");
    expect(body.title).toBe("Item with Image");
    // images should contain signed URLs, not raw file IDs
    expect(body.images).toHaveLength(1);
    expect(body.images[0]).toContain("mock-s3.example.com");
    expect(body.images[0]).not.toContain("file:");

    itemId = body.id;
  });

  test("GET /api/v1/items/{id} - should return signed URLs in images field", async ({
    request,
  }) => {
    const response = await request.get(`/api/v1/items/${itemId}`);

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.id).toBe(itemId);
    // images should contain signed URLs, not raw file IDs
    expect(body.images).toHaveLength(1);
    expect(body.images[0]).toMatch(/^https:\/\//);
    expect(body.images[0]).not.toContain("file:");
  });

  test("GET /api/v1/items - should return signed URLs in images field for list", async ({
    request,
  }) => {
    const response = await request.get("/api/v1/items");

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body).toBeInstanceOf(Array);

    // Find our item with images
    const itemWithImages = body.find((item: { id: number }) => item.id === itemId);
    expect(itemWithImages).toBeDefined();
    expect(itemWithImages.images).toHaveLength(1);
    expect(itemWithImages.images[0]).toContain("mock-s3.example.com");
  });

  test("PUT /api/v1/items/{id} - should handle adding new file IDs", async ({
    request,
  }) => {
    // Upload a second file
    const uploadResponse = await request.post("/api/v1/upload/presigned", {
      data: {
        filename: "second-image.png",
        contentType: "image/png",
        size: 2048,
      },
    });
    expect(uploadResponse.status()).toBe(201);
    const uploadBody = await uploadResponse.json();
    const secondFileId = uploadBody.fileId;

    // Update item with both images
    const response = await request.put(`/api/v1/items/${itemId}`, {
      data: {
        images: [`file:${fileId}`, `file:${secondFileId}`],
      },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    // images should contain signed URLs
    expect(body.images).toHaveLength(2);
    expect(body.images[0]).toContain("mock-s3.example.com");
    expect(body.images[1]).toContain("mock-s3.example.com");
  });

  test("PUT /api/v1/items/{id} - should handle removing file IDs", async ({
    request,
  }) => {
    // Update item to keep only the first image
    const response = await request.put(`/api/v1/items/${itemId}`, {
      data: {
        images: [`file:${fileId}`],
      },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.images).toHaveLength(1);
  });

  test("POST /api/v1/items - should reject invalid file IDs", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/items", {
      data: {
        title: "Item with Invalid File ID",
        visibility: "public",
        images: ["file:999999"], // Non-existent file ID
      },
    });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body).toHaveProperty("error");
    expect(body.error).toContain("Invalid");
  });

  test("GET /api/v1/preview/{id} - should return signed URLs in images field", async ({
    request,
  }) => {
    const response = await request.get(`/api/v1/preview/${itemId}`);

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.id).toBe(itemId);
    expect(body.images).toHaveLength(1);
    expect(body.images[0]).toContain("mock-s3.example.com");
  });

  test("DELETE /api/v1/items/{id} - should delete associated files", async ({
    request,
  }) => {
    // Delete the item
    const response = await request.delete(`/api/v1/items/${itemId}`);
    expect(response.status()).toBe(200);

    // Verify item is deleted
    const getResponse = await request.get(`/api/v1/items/${itemId}`);
    expect(getResponse.status()).toBe(404);

    // File should also be deleted (attempting to use it should fail)
    const createResponse = await request.post("/api/v1/items", {
      data: {
        title: "Item with Deleted File",
        visibility: "public",
        images: [`file:${fileId}`],
      },
    });
    expect(createResponse.status()).toBe(400);
  });
});
