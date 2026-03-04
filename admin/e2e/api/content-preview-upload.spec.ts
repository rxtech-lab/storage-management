import { test, expect } from "@playwright/test";

test.describe.serial("Content Preview Upload API", () => {
  test("POST /api/v1/upload/content-preview - video type returns imageUrl, videoUrl, and id", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/upload/content-preview", {
      data: [
        {
          filename: "test-video.mp4",
          type: "video",
          title: "Test Video",
          description: "A test video",
          mime_type: "video/mp4",
          size: 1048576,
          file_path: "videos/test-video.mp4",
          video_length: 120,
        },
      ],
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body).toHaveLength(1);
    expect(body[0]).toHaveProperty("id");
    expect(body[0]).toHaveProperty("imageUrl");
    expect(body[0]).toHaveProperty("videoUrl");
    expect(body[0].imageUrl).toContain("mock-s3.example.com");
    expect(body[0].videoUrl).toContain("mock-s3.example.com");
  });

  test("POST /api/v1/upload/content-preview - image type returns imageUrl and id only", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/upload/content-preview", {
      data: [
        {
          filename: "test-photo.jpg",
          type: "image",
          title: "Test Photo",
          mime_type: "image/jpeg",
          size: 204800,
          file_path: "images/test-photo.jpg",
        },
      ],
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body).toHaveLength(1);
    expect(body[0]).toHaveProperty("id");
    expect(body[0]).toHaveProperty("imageUrl");
    expect(body[0]).not.toHaveProperty("videoUrl");
    expect(body[0].imageUrl).toContain("mock-s3.example.com");
  });

  test("POST /api/v1/upload/content-preview - mixed batch with video and image", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/upload/content-preview", {
      data: [
        {
          filename: "clip.mp4",
          type: "video",
          title: "Video Clip",
          mime_type: "video/mp4",
          size: 2097152,
          file_path: "videos/clip.mp4",
          video_length: 30,
        },
        {
          filename: "photo.png",
          type: "image",
          title: "Photo",
          mime_type: "image/png",
          size: 102400,
          file_path: "images/photo.png",
        },
        {
          filename: "another.mov",
          type: "video",
          title: "Another Video",
          mime_type: "video/quicktime",
          size: 5242880,
          file_path: "videos/another.mov",
          video_length: 60,
        },
      ],
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body).toHaveLength(3);

    // First: video
    expect(body[0]).toHaveProperty("imageUrl");
    expect(body[0]).toHaveProperty("videoUrl");
    expect(body[0]).toHaveProperty("id");

    // Second: image
    expect(body[1]).toHaveProperty("imageUrl");
    expect(body[1]).not.toHaveProperty("videoUrl");
    expect(body[1]).toHaveProperty("id");

    // Third: video
    expect(body[2]).toHaveProperty("imageUrl");
    expect(body[2]).toHaveProperty("videoUrl");
    expect(body[2]).toHaveProperty("id");

    // All IDs should be unique
    const ids = body.map((item: { id: string }) => item.id);
    expect(new Set(ids).size).toBe(3);
  });

  test("POST /api/v1/upload/content-preview - empty array returns empty array", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/upload/content-preview", {
      data: [],
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body).toEqual([]);
  });

  test("POST /api/v1/upload/content-preview - invalid type returns 400", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/upload/content-preview", {
      data: [
        {
          filename: "test.pdf",
          type: "file",
          title: "Test File",
          mime_type: "application/pdf",
          size: 1024,
          file_path: "files/test.pdf",
        },
      ],
    });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body).toHaveProperty("error");
  });

  test("POST /api/v1/upload/content-preview - missing filename returns 400", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/upload/content-preview", {
      data: [
        {
          type: "image",
          title: "Test",
          mime_type: "image/jpeg",
          size: 1024,
          file_path: "images/test.jpg",
        },
      ],
    });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body).toHaveProperty("error");
  });

  test("POST /api/v1/upload/content-preview - missing required fields returns 400", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/upload/content-preview", {
      data: [
        {
          filename: "test.jpg",
          type: "image",
          // missing title, mime_type, size, file_path
        },
      ],
    });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body).toHaveProperty("error");
  });

  test("POST /api/v1/upload/content-preview - video without video_length returns 400", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/upload/content-preview", {
      data: [
        {
          filename: "test.mp4",
          type: "video",
          title: "Test Video",
          mime_type: "video/mp4",
          size: 1048576,
          file_path: "videos/test.mp4",
          // missing video_length
        },
      ],
    });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body).toHaveProperty("error");
  });
});
