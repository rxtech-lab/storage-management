import { test, expect } from '@playwright/test';

test.describe('Preview API', () => {
  let publicItemId: number;
  let privateItemId: number;

  test.beforeAll(async ({ request }) => {
    // Create a public item
    const publicResponse = await request.post('/api/v1/items', {
      data: {
        title: 'Public Item',
        description: 'This is public',
        visibility: 'public',
      },
    });
    const publicBody = await publicResponse.json();
    publicItemId = publicBody.data.id;

    // Create a private item
    const privateResponse = await request.post('/api/v1/items', {
      data: {
        title: 'Private Item',
        description: 'This is private',
        visibility: 'private',
      },
    });
    const privateBody = await privateResponse.json();
    privateItemId = privateBody.data.id;
  });

  test('GET /api/v1/preview/{id} - should get public item without auth', async ({ request }) => {
    const response = await request.get(`/api/v1/preview/${publicItemId}`);

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.data.id).toBe(publicItemId);
    expect(body.data.title).toBe('Public Item');
    expect(body.data.visibility).toBe('public');
  });

  test('GET /api/v1/preview/{id} - should get private item with auth (e2e mode)', async ({ request }) => {
    // In e2e mode, auth is bypassed so this should work
    const response = await request.get(`/api/v1/preview/${privateItemId}`);

    // Should succeed in e2e mode since auth is bypassed
    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.data.id).toBe(privateItemId);
    expect(body.data.title).toBe('Private Item');
  });

  test('GET /api/v1/preview/999999 - should return 404 for non-existent item', async ({ request }) => {
    const response = await request.get('/api/v1/preview/999999');

    expect(response.status()).toBe(404);
    const body = await response.json();
    expect(body).toHaveProperty('error');
  });

  test.afterAll(async ({ request }) => {
    // Clean up test items
    await request.delete(`/api/v1/items/${publicItemId}`);
    await request.delete(`/api/v1/items/${privateItemId}`);
  });
});
