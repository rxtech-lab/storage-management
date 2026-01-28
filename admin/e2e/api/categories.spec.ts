import { test, expect } from '@playwright/test';

test.describe.serial('Categories API', () => {
  let createdCategoryId: number;

  test('POST /api/v1/categories - should create a new category', async ({ request }) => {
    const response = await request.post('/api/v1/categories', {
      data: {
        name: 'Test Category',
        description: 'Created via API test',
      },
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body.data).toHaveProperty('id');
    expect(body.data.name).toBe('Test Category');
    expect(body.data.description).toBe('Created via API test');

    createdCategoryId = body.data.id;
  });

  test('GET /api/v1/categories - should list all categories', async ({ request }) => {
    const response = await request.get('/api/v1/categories');

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.data).toBeInstanceOf(Array);
    expect(body.data.length).toBeGreaterThan(0);
  });

  test('GET /api/v1/categories/{id} - should get category by ID', async ({ request }) => {
    const response = await request.get(`/api/v1/categories/${createdCategoryId}`);

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.data.id).toBe(createdCategoryId);
    expect(body.data.name).toBe('Test Category');
  });

  test('PUT /api/v1/categories/{id} - should update category', async ({ request }) => {
    const response = await request.put(`/api/v1/categories/${createdCategoryId}`, {
      data: {
        name: 'Updated Category',
        description: 'Updated via API test',
      },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.data.name).toBe('Updated Category');
  });

  test('DELETE /api/v1/categories/{id} - should delete category', async ({ request }) => {
    const response = await request.delete(`/api/v1/categories/${createdCategoryId}`);

    expect(response.status()).toBe(200);

    // Verify category is deleted
    const getResponse = await request.get(`/api/v1/categories/${createdCategoryId}`);
    expect(getResponse.status()).toBe(404);
  });

  test('POST /api/v1/categories - should validate required fields', async ({ request }) => {
    const response = await request.post('/api/v1/categories', {
      data: {
        description: 'Missing name',
      },
    });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body).toHaveProperty('error');
  });
});
