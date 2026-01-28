import { test, expect } from '@playwright/test';

test.describe.serial('Authors API', () => {
  let createdAuthorId: number;

  test('POST /api/v1/authors - should create a new author', async ({ request }) => {
    const response = await request.post('/api/v1/authors', {
      data: {
        name: 'Test Author',
        bio: 'Created via API test',
      },
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body.data).toHaveProperty('id');
    expect(body.data.name).toBe('Test Author');
    expect(body.data.bio).toBe('Created via API test');

    createdAuthorId = body.data.id;
  });

  test('GET /api/v1/authors - should list all authors', async ({ request }) => {
    const response = await request.get('/api/v1/authors');

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.data).toBeInstanceOf(Array);
    expect(body.data.length).toBeGreaterThan(0);
  });

  test('GET /api/v1/authors/{id} - should get author by ID', async ({ request }) => {
    const response = await request.get(`/api/v1/authors/${createdAuthorId}`);

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.data.id).toBe(createdAuthorId);
    expect(body.data.name).toBe('Test Author');
  });

  test('PUT /api/v1/authors/{id} - should update author', async ({ request }) => {
    const response = await request.put(`/api/v1/authors/${createdAuthorId}`, {
      data: {
        name: 'Updated Author',
        bio: 'Updated via API test',
      },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.data.name).toBe('Updated Author');
  });

  test('DELETE /api/v1/authors/{id} - should delete author', async ({ request }) => {
    const response = await request.delete(`/api/v1/authors/${createdAuthorId}`);

    expect(response.status()).toBe(200);

    // Verify author is deleted
    const getResponse = await request.get(`/api/v1/authors/${createdAuthorId}`);
    expect(getResponse.status()).toBe(404);
  });

  test('POST /api/v1/authors - should validate required fields', async ({ request }) => {
    const response = await request.post('/api/v1/authors', {
      data: {
        bio: 'Missing name',
      },
    });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body).toHaveProperty('error');
  });
});
