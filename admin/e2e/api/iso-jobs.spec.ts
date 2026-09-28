import { test, expect } from "@playwright/test";

test.describe.serial("ISO Jobs API", () => {
  const USER_ID = `iso-jobs-api-test-user-${crypto.randomUUID()}`;
  const OTHER_USER_ID = `iso-jobs-api-other-user-${crypto.randomUUID()}`;
  const headers = { "X-Test-User-Id": USER_ID };
  const otherHeaders = { "X-Test-User-Id": OTHER_USER_ID };
  const jobId = crypto.randomUUID();

  const snapshot = (overrides: Record<string, unknown> = {}) => ({
    kind: "generate",
    title: "backup",
    status: "running",
    hostName: "studio-mac",
    progress: 0.25,
    doneCount: 1,
    totalCount: 4,
    doneBytes: 25,
    totalBytes: 100,
    startedAt: "2026-09-28T08:00:00.000Z",
    tasks: [
      { section: "iso", name: "backup_1.iso", status: "done", progress: 1, doneBytes: 25, totalBytes: 25 },
      { section: "iso", name: "backup_2.iso", status: "copying", detail: "copying files", progress: 0, doneBytes: 0, totalBytes: 25 },
    ],
    ...overrides,
  });

  test("PUT /api/v1/iso-jobs/{id} - creates a job from a snapshot", async ({ request }) => {
    const response = await request.put(`/api/v1/iso-jobs/${jobId}`, {
      headers,
      data: snapshot(),
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.id).toBe(jobId);
    expect(body.userId).toBe(USER_ID);
    expect(body.status).toBe("running");
    expect(body.hostName).toBe("studio-mac");
    expect(body.tasks).toHaveLength(2);
    expect(body.tasks[0].name).toBe("backup_1.iso");
    expect(body.tasks[1].position).toBe(1);
    expect(body.tasks[1].detail).toBe("copying files");
  });

  test("PUT /api/v1/iso-jobs/{id} - replaces progress rows on update", async ({ request }) => {
    const response = await request.put(`/api/v1/iso-jobs/${jobId}`, {
      headers,
      data: snapshot({
        status: "completed",
        progress: 1,
        doneCount: 4,
        doneBytes: 100,
        finishedAt: "2026-09-28T08:10:00.000Z",
        tasks: [
          { section: "iso", name: "backup_1.iso", status: "done", progress: 1, doneBytes: 25, totalBytes: 25 },
        ],
      }),
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.status).toBe("completed");
    expect(body.finishedAt).not.toBeNull();
    expect(body.tasks).toHaveLength(1);
  });

  test("PUT /api/v1/iso-jobs/{id} - rejects invalid snapshots", async ({ request }) => {
    const response = await request.put(`/api/v1/iso-jobs/${jobId}`, {
      headers,
      data: snapshot({ status: "exploded", progress: 2 }),
    });

    expect(response.status()).toBe(400);
  });

  test("GET /api/v1/iso-jobs - lists the user's jobs", async ({ request }) => {
    const response = await request.get("/api/v1/iso-jobs", { headers });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.data).toHaveLength(1);
    expect(body.data[0].id).toBe(jobId);
    expect(body.data[0]).not.toHaveProperty("tasks");
    expect(body.pagination.totalCount).toBe(1);
  });

  test("GET /api/v1/iso-jobs - filters by kind", async ({ request }) => {
    const response = await request.get("/api/v1/iso-jobs?kind=burn", { headers });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.data).toHaveLength(0);
  });

  test("GET /api/v1/iso-jobs/{id} - returns the job with its rows", async ({ request }) => {
    const response = await request.get(`/api/v1/iso-jobs/${jobId}`, { headers });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.title).toBe("backup");
    expect(body.tasks).toHaveLength(1);
  });

  test("other users cannot read, overwrite or delete the job", async ({ request }) => {
    const get = await request.get(`/api/v1/iso-jobs/${jobId}`, { headers: otherHeaders });
    expect(get.status()).toBe(403);

    const put = await request.put(`/api/v1/iso-jobs/${jobId}`, {
      headers: otherHeaders,
      data: snapshot(),
    });
    expect(put.status()).toBe(403);

    const del = await request.delete(`/api/v1/iso-jobs/${jobId}`, { headers: otherHeaders });
    expect(del.status()).toBe(403);

    const list = await request.get("/api/v1/iso-jobs", { headers: otherHeaders });
    expect((await list.json()).data).toHaveLength(0);
  });

  test("PUT /api/v1/iso-jobs/{id} - accepts upload jobs with file rows", async ({ request }) => {
    const uploadJobId = crypto.randomUUID();
    const response = await request.put(`/api/v1/iso-jobs/${uploadJobId}`, {
      headers,
      data: snapshot({
        kind: "upload",
        title: "Upload to Camera roll",
        doneCount: 1,
        totalCount: 3,
        tasks: [
          { section: "file", name: "clip.mov", status: "compressing", detail: "videos/clip.mov", progress: 0.4, doneBytes: 40, totalBytes: 100 },
          { section: "file", name: "broken.jpg", status: "failed", detail: "photos/broken.jpg", progress: 0, doneBytes: 0, totalBytes: 10, error: "unreadable" },
          { section: "file", name: "photo.jpg", status: "done", detail: "photos/photo.jpg", progress: 1, doneBytes: 20, totalBytes: 20 },
        ],
      }),
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.kind).toBe("upload");
    expect(body.tasks).toHaveLength(3);
    expect(body.tasks[0].section).toBe("file");
    expect(body.tasks[0].detail).toBe("videos/clip.mov");
    expect(body.tasks[1].error).toBe("unreadable");

    const list = await request.get("/api/v1/iso-jobs?kind=upload", { headers });
    expect(list.status()).toBe(200);
    const listBody = await list.json();
    expect(listBody.data.map((job: { id: string }) => job.id)).toEqual([uploadJobId]);

    const del = await request.delete(`/api/v1/iso-jobs/${uploadJobId}`, { headers });
    expect(del.status()).toBe(200);
  });

  test("DELETE /api/v1/iso-jobs/{id} - deletes the job", async ({ request }) => {
    const response = await request.delete(`/api/v1/iso-jobs/${jobId}`, { headers });
    expect(response.status()).toBe(200);

    const getResponse = await request.get(`/api/v1/iso-jobs/${jobId}`, { headers });
    expect(getResponse.status()).toBe(404);
  });
});
