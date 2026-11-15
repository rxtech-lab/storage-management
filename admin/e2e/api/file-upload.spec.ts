import { test, expect } from "@playwright/test";

test.describe.serial("File Upload API", () => {
  test.use({
    extraHTTPHeaders: { "X-Test-User-Id": `file-upload-${crypto.randomUUID()}` },
  });
  let fileId: string;
  let itemId: string;

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
        visibility: "publicAccess",
        images: [`file:${fileId}`],
      },
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body).toHaveProperty("id");
    expect(body.title).toBe("Item with Image");
    // images should be objects with id and url, containing signed URLs
    expect(body.images).toHaveLength(1);
    expect(body.images[0]).toHaveProperty("id");
    expect(body.images[0]).toHaveProperty("url");
    expect(body.images[0].url).toContain("mock-s3.example.com");
    expect(body.images[0].url).not.toContain("file:");

    itemId = body.id;
  });

  test("GET /api/v1/items/{id} - should return signed URLs in images field", async ({
    request,
  }) => {
    const response = await request.get(`/api/v1/items/${itemId}`);

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.id).toBe(itemId);
    // images should be objects with id and url, containing signed URLs
    expect(body.images).toHaveLength(1);
    expect(body.images[0]).toHaveProperty("id");
    expect(body.images[0]).toHaveProperty("url");
    expect(body.images[0].url).toMatch(/^https:\/\//);
    expect(body.images[0].url).not.toContain("file:");
  });

  test("GET /api/v1/items - should return signed URLs in images field for list", async ({
    request,
  }) => {
    const response = await request.get("/api/v1/items");

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.data).toBeInstanceOf(Array);

    // Find our item with images
    const itemWithImages = body.data.find((item: { id: string }) => item.id === itemId);
    expect(itemWithImages).toBeDefined();
    expect(itemWithImages.images).toHaveLength(1);
    expect(itemWithImages.images[0]).toHaveProperty("id");
    expect(itemWithImages.images[0]).toHaveProperty("url");
    expect(itemWithImages.images[0].url).toContain("mock-s3.example.com");
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
    // images should be objects with id and url, containing signed URLs
    expect(body.images).toHaveLength(2);
    expect(body.images[0]).toHaveProperty("id");
    expect(body.images[0]).toHaveProperty("url");
    expect(body.images[0].url).toContain("mock-s3.example.com");
    expect(body.images[1]).toHaveProperty("id");
    expect(body.images[1]).toHaveProperty("url");
    expect(body.images[1].url).toContain("mock-s3.example.com");
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
        visibility: "publicAccess",
        images: ["file:999999"], // Non-existent file ID
      },
    });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body).toHaveProperty("error");
    expect(body.error).toContain("Invalid");
  });

  test("DELETE /api/v1/items/{id} - should preserve files until permanently deleted", async ({
    request,
  }) => {
    // Delete the item
    const response = await request.delete(`/api/v1/items/${itemId}`);
    expect(response.status()).toBe(204);

    // Verify item is deleted
    const getResponse = await request.get(`/api/v1/items/${itemId}`);
    expect(getResponse.status()).toBe(404);

    // Recycled items retain their files so restoring preserves their images.
    const recycleResponse = await request.get("/api/v1/recycle-bin");
    expect(recycleResponse.status()).toBe(200);
    expect((await recycleResponse.json()).items).toEqual(
      expect.arrayContaining([expect.objectContaining({ id: itemId })]),
    );

    const restoreResponse = await request.post(`/api/v1/recycle-bin/${itemId}`);
    expect(restoreResponse.status()).toBe(204);
    const restoredResponse = await request.get(`/api/v1/items/${itemId}`);
    expect(restoredResponse.status()).toBe(200);
    expect((await restoredResponse.json()).images).toEqual([
      expect.objectContaining({ id: fileId, url: expect.stringContaining("mock-s3.example.com") }),
    ]);

    const deleteAgainResponse = await request.delete(`/api/v1/items/${itemId}`);
    expect(deleteAgainResponse.status()).toBe(204);
    const purgeResponse = await request.delete(`/api/v1/recycle-bin/${itemId}`);
    expect(purgeResponse.status()).toBe(204);

    // Permanent deletion removes file records, preventing their reuse.
    const createResponse = await request.post("/api/v1/items", {
      data: {
        title: "Item with Deleted File",
        visibility: "publicAccess",
        images: [`file:${fileId}`],
      },
    });
    expect(createResponse.status()).toBe(400);
  });
});
