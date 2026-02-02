import { test, expect } from '@playwright/test';
import { DashboardStatsResponseSchema, DashboardRecentItemSchema } from '../../lib/schemas/dashboard';
import { z } from 'zod';

test.describe('Dashboard API', () => {
  test('GET /api/v1/dashboard/stats - should return valid dashboard stats', async ({ request }) => {
    const response = await request.get('/api/v1/dashboard/stats');

    expect(response.status()).toBe(200);
    const body = await response.json();

    // Validate response against Zod schema
    const result = DashboardStatsResponseSchema.safeParse(body);
    if (!result.success) {
      console.error('Validation errors:', result.error.format());
    }
    expect(result.success).toBe(true);
  });

  test('GET /api/v1/dashboard/stats - should return correct types for counts', async ({ request }) => {
    const response = await request.get('/api/v1/dashboard/stats');

    expect(response.status()).toBe(200);
    const body = await response.json();

    // Validate counts are non-negative integers
    expect(body.totalItems).toBeGreaterThanOrEqual(0);
    expect(body.publicItems).toBeGreaterThanOrEqual(0);
    expect(body.privateItems).toBeGreaterThanOrEqual(0);
    expect(body.totalCategories).toBeGreaterThanOrEqual(0);
    expect(body.totalLocations).toBeGreaterThanOrEqual(0);
    expect(body.totalAuthors).toBeGreaterThanOrEqual(0);

    // Sum of public and private should equal total
    expect(body.publicItems + body.privateItems).toBe(body.totalItems);
  });

  test('GET /api/v1/dashboard/stats - should return valid recent items', async ({ request }) => {
    const response = await request.get('/api/v1/dashboard/stats');

    expect(response.status()).toBe(200);
    const body = await response.json();

    expect(body.recentItems).toBeInstanceOf(Array);
    expect(body.recentItems.length).toBeLessThanOrEqual(5);

    // Validate each recent item against schema
    for (const item of body.recentItems) {
      const result = DashboardRecentItemSchema.safeParse(item);
      if (!result.success) {
        console.error('Item validation errors:', result.error.format());
      }
      expect(result.success).toBe(true);

      // Additional type checks
      expect(['publicAccess', 'privateAccess']).toContain(item.visibility);
      expect(typeof item.id).toBe('number');
      expect(typeof item.title).toBe('string');
    }
  });

  test('GET /api/v1/dashboard/stats - recentItems should be sorted by updatedAt descending', async ({ request }) => {
    const response = await request.get('/api/v1/dashboard/stats');

    expect(response.status()).toBe(200);
    const body = await response.json();

    if (body.recentItems.length > 1) {
      for (let i = 0; i < body.recentItems.length - 1; i++) {
        const current = new Date(body.recentItems[i].updatedAt);
        const next = new Date(body.recentItems[i + 1].updatedAt);
        expect(current.getTime()).toBeGreaterThanOrEqual(next.getTime());
      }
    }
  });
});
