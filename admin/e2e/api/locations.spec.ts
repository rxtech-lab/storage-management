import { test, expect } from '@playwright/test';

test.describe.serial('Locations API', () => {
  let createdLocationId: number;

  test('POST /api/v1/locations - should create a new location', async ({ request }) => {
    const response = await request.post('/api/v1/locations', {
      data: {
        title: 'Test Location',
        latitude: 37.7749,
        longitude: -122.4194,
      },
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body).toHaveProperty('id');
    expect(body.title).toBe('Test Location');
    expect(body.latitude).toBe(37.7749);
    expect(body.longitude).toBe(-122.4194);

    createdLocationId = body.id;
  });

  test('GET /api/v1/locations - should list all locations', async ({ request }) => {
    const response = await request.get('/api/v1/locations');

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body).toBeInstanceOf(Array);
    expect(body.length).toBeGreaterThan(0);
  });

  test('GET /api/v1/locations/{id} - should get location by ID', async ({ request }) => {
    const response = await request.get(`/api/v1/locations/${createdLocationId}`);

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.id).toBe(createdLocationId);
    expect(body.title).toBe('Test Location');
  });

  test('PUT /api/v1/locations/{id} - should update location', async ({ request }) => {
    const response = await request.put(`/api/v1/locations/${createdLocationId}`, {
      data: {
        title: 'Updated Location',
        latitude: 40.7128,
        longitude: -74.0060,
      },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.title).toBe('Updated Location');
    expect(body.latitude).toBe(40.7128);
  });

  test('DELETE /api/v1/locations/{id} - should delete location', async ({ request }) => {
    const response = await request.delete(`/api/v1/locations/${createdLocationId}`);

    expect(response.status()).toBe(200);

    // Verify location is deleted
    const getResponse = await request.get(`/api/v1/locations/${createdLocationId}`);
    expect(getResponse.status()).toBe(404);
  });

  test('POST /api/v1/locations - should validate required fields', async ({ request }) => {
    const response = await request.post('/api/v1/locations', {
      data: {
        title: 'Missing coordinates',
      },
    });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body).toHaveProperty('error');
  });
});
