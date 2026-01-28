import { test, expect } from '@playwright/test';

test.describe.serial('Position Schemas API', () => {
  let createdSchemaId: number;

  test('POST /api/v1/position-schemas - should create a new position schema', async ({ request }) => {
    const response = await request.post('/api/v1/position-schemas', {
      data: {
        name: 'Test Schema',
        schema: {
          type: 'object',
          properties: {
            shelf: { type: 'string' },
            row: { type: 'number' },
          },
          required: ['shelf'],
        },
      },
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body.data).toHaveProperty('id');
    expect(body.data.name).toBe('Test Schema');
    expect(body.data.schema).toHaveProperty('type', 'object');

    createdSchemaId = body.data.id;
  });

  test('GET /api/v1/position-schemas - should list all position schemas', async ({ request }) => {
    const response = await request.get('/api/v1/position-schemas');

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.data).toBeInstanceOf(Array);
    expect(body.data.length).toBeGreaterThan(0);
  });

  test('GET /api/v1/position-schemas/{id} - should get position schema by ID', async ({ request }) => {
    const response = await request.get(`/api/v1/position-schemas/${createdSchemaId}`);

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.data.id).toBe(createdSchemaId);
    expect(body.data.name).toBe('Test Schema');
  });

  test('PUT /api/v1/position-schemas/{id} - should update position schema', async ({ request }) => {
    const response = await request.put(`/api/v1/position-schemas/${createdSchemaId}`, {
      data: {
        name: 'Updated Schema',
        schema: {
          type: 'object',
          properties: {
            shelf: { type: 'string' },
            row: { type: 'number' },
            column: { type: 'number' },
          },
          required: ['shelf', 'row'],
        },
      },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.data.name).toBe('Updated Schema');
  });

  test('DELETE /api/v1/position-schemas/{id} - should delete position schema', async ({ request }) => {
    const response = await request.delete(`/api/v1/position-schemas/${createdSchemaId}`);

    expect(response.status()).toBe(200);

    // Verify schema is deleted
    const getResponse = await request.get(`/api/v1/position-schemas/${createdSchemaId}`);
    expect(getResponse.status()).toBe(404);
  });

  test('POST /api/v1/position-schemas - should validate required fields', async ({ request }) => {
    const response = await request.post('/api/v1/position-schemas', {
      data: {
        name: 'Missing schema',
      },
    });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body).toHaveProperty('error');
  });
});
