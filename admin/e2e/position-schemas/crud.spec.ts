import { test, expect } from '@playwright/test';

test.describe.serial('Position Schema UI CRUD', () => {
  test.beforeEach(async ({ page }) => {
    page.on('console', (msg) => console.log(`[Browser ${msg.type()}]:`, msg.text()));
    page.on('pageerror', (error) => console.log('[Browser Error]:', error.message));
  });

  test('should navigate to position schemas page', async ({ page }) => {
    await page.goto('/position-schemas');
    await page.waitForLoadState('networkidle');

    await expect(page.locator('h1')).toContainText('Position Schemas');
    await expect(page.getByTestId('position-schemas-new-button')).toBeVisible();
  });

  test('should create a new position schema with visual editor', async ({ page }) => {
    const timestamp = Date.now();
    const schemaName = `Test Schema ${timestamp}`;

    await page.goto('/position-schemas');
    await page.waitForLoadState('networkidle');

    // Click New Schema button
    await page.getByTestId('position-schemas-new-button').click();
    await page.waitForURL('/position-schemas/new');

    // Wait for form to be visible
    await expect(page.getByTestId('position-schema-form')).toBeVisible();

    // Fill name
    await page.getByTestId('position-schema-name-input').fill(schemaName);

    // Add a property using visual editor
    await page.getByTestId('property-list-add-button').click();
    await page.getByTestId('property-name-input-0').fill('shelf');
    await page.getByTestId('property-title-input-0').fill('Shelf Number');

    // Submit form
    await page.getByTestId('position-schema-submit-button').click();

    // Wait for redirect to list
    await page.waitForURL('/position-schemas');

    // Verify schema appears in list
    await expect(page.getByText(schemaName)).toBeVisible();
  });

  test('should create schema using raw JSON editor', async ({ page }) => {
    const timestamp = Date.now();
    const schemaName = `JSON Schema ${timestamp}`;

    await page.goto('/position-schemas/new');
    await page.waitForLoadState('networkidle');

    // Fill name
    await page.getByTestId('position-schema-name-input').fill(schemaName);

    // Switch to Raw JSON tab
    await page.getByTestId('json-schema-tab-raw').click();

    // Enter raw JSON
    const rawJson = JSON.stringify({
      type: 'object',
      properties: {
        drawer: { type: 'string', title: 'Drawer' },
        slot: { type: 'integer', title: 'Slot Number' }
      },
      required: ['drawer']
    }, null, 2);

    await page.getByTestId('json-schema-raw-textarea').fill(rawJson);

    // Submit
    await page.getByTestId('position-schema-submit-button').click();

    // Verify redirect and schema visible
    await page.waitForURL('/position-schemas');
    await expect(page.getByText(schemaName)).toBeVisible();
  });

  test('should edit an existing position schema', async ({ page }) => {
    // First create a schema to edit
    const timestamp = Date.now();
    const originalName = `Edit Test ${timestamp}`;
    const updatedName = `Updated ${timestamp}`;

    await page.goto('/position-schemas/new');
    await page.waitForLoadState('networkidle');
    await page.getByTestId('position-schema-name-input').fill(originalName);
    await page.getByTestId('position-schema-submit-button').click();
    await page.waitForURL('/position-schemas');

    // Find and click edit button on the schema card
    const editButton = page.locator(`[data-testid^="position-schema-edit-button-"]`).first();
    await editButton.click();

    // Wait for edit page
    await page.waitForURL(/\/position-schemas\/\d+/);
    await expect(page.getByTestId('position-schema-form')).toBeVisible();

    // Update name
    await page.getByTestId('position-schema-name-input').clear();
    await page.getByTestId('position-schema-name-input').fill(updatedName);

    // Submit
    await page.getByTestId('position-schema-submit-button').click();

    // Verify redirect and updated name
    await page.waitForURL('/position-schemas');
    await expect(page.getByText(updatedName)).toBeVisible();
  });

  test('should delete position schema from list page', async ({ page }) => {
    // Create a schema to delete
    const timestamp = Date.now();
    const schemaName = `Delete Test ${timestamp}`;

    await page.goto('/position-schemas/new');
    await page.waitForLoadState('networkidle');
    await page.getByTestId('position-schema-name-input').fill(schemaName);
    await page.getByTestId('position-schema-submit-button').click();
    await page.waitForURL('/position-schemas');

    // Verify schema exists
    await expect(page.getByText(schemaName)).toBeVisible();

    // Find and click delete button directly on card
    const deleteButton = page.locator(`[data-testid^="position-schema-delete-button-"]`).first();
    await deleteButton.click();

    // Wait for page refresh (form action submits)
    await page.waitForLoadState('networkidle');

    // Verify schema is removed
    await expect(page.getByText(schemaName)).not.toBeVisible();
  });

  test('should cancel schema creation', async ({ page }) => {
    await page.goto('/position-schemas/new');
    await page.waitForLoadState('networkidle');

    // Fill some data
    await page.getByTestId('position-schema-name-input').fill('Should Not Be Created');

    // Click cancel
    await page.getByTestId('position-schema-cancel-button').click();

    // Should navigate back to list
    await page.waitForURL('/position-schemas');
  });

  test('should show validation error for empty name', async ({ page }) => {
    await page.goto('/position-schemas/new');
    await page.waitForLoadState('networkidle');

    // Clear name and submit
    await page.getByTestId('position-schema-name-input').clear();
    await page.getByTestId('position-schema-submit-button').click();

    // Should show error and stay on page
    await expect(page.getByText('Name is required')).toBeVisible();
    await expect(page).toHaveURL('/position-schemas/new');
  });

  test('should show error for invalid JSON schema', async ({ page }) => {
    await page.goto('/position-schemas/new');
    await page.waitForLoadState('networkidle');

    await page.getByTestId('position-schema-nam e-input').fill('Invalid JSON Test');

    // Switch to Raw JSON tab
    await page.getByTestId('json-schema-tab-raw').click();

    // Enter invalid JSON
    await page.getByTestId('json-schema-raw-textarea').fill('{ invalid json }');

    // Error should appear
    await expect(page.getByTestId('json-schema-error')).toBeVisible();
  });
});
