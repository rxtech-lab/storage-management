import { test, expect } from '@playwright/test';

test.describe('Item Creation', () => {
  test.beforeEach(async ({ page }) => {
    // Listen for console messages
    page.on('console', (msg) => {
      console.log(`[Browser ${msg.type()}]:`, msg.text());
    });

    // Listen for page errors
    page.on('pageerror', (error) => {
      console.log('[Browser Error]:', error.message);
    });

    await page.goto('/items');
    await page.waitForLoadState('networkidle');
  });

  test('should create a new item with title only', async ({ page }) => {
    // Click New Item button
    await page.getByTestId('items-new-button').click();

    // Wait for navigation to complete
    await page.waitForURL('/items/new');
    await page.waitForLoadState('networkidle');

    // Wait for form to be visible
    await expect(page.getByTestId('item-form')).toBeVisible();

    // Fill in title (required field)
    const timestamp = Date.now();
    await page.getByTestId('item-title-input').fill(`Test Item ${timestamp}`);

    // Submit form
    await page.getByTestId('item-submit-button').click();

    // Wait for redirect to item detail page
    await page.waitForURL(/\/items\/\d+/);

    // Verify we're on the item detail page
    expect(page.url()).toMatch(/\/items\/\d+$/);

    // Verify item title appears on detail page
    await expect(page.locator('h1')).toContainText('Test Item');
  });
});
