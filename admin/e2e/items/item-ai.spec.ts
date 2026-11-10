import { test, expect } from "@playwright/test";
import QRCode from "qrcode";
const aiResult = {
  draft: { title: "Researched Camera", description: "Camera description from official sources", originalQrCode: null, category: "Photography", author: "Camera Maker", tags: ["camera", "portable"] },
  sources: [{ title: "Official product page", url: "https://example.com/camera" }],
};

test("creation dropdown offers form and AI in separate views", async ({ page }) => {
  await page.goto("/items");
  await page.getByTestId("items-new-button").first().click();
  await expect(page.getByRole("menuitem", { name: "Create using form" })).toBeVisible();
  await page.getByRole("menuitem", { name: "Create using AI" }).click();
  await expect(page.getByRole("dialog")).toContainText("Create item using AI");
  await expect(page.getByRole("button", { name: "Generate draft" })).toBeDisabled();
  await page.getByRole("button", { name: "Close", exact: true }).click();
  await expect(page.getByTestId("item-form")).toBeVisible();
});

test("QR image scan previews its value and persists it with the item", async ({ page, request }) => {
  await page.goto("/items/new");
  const value = `https://example.com/item/${Date.now()}`;
  const png = await QRCode.toBuffer(value);
  await page.getByRole("button", { name: "Scan QR", exact: true }).click();
  await page.getByLabel("QR code image", { exact: true }).setInputFiles({ name: "qr.png", mimeType: "image/png", buffer: png });
  await expect(page.getByTestId("qr-decoded-value")).toHaveText(value);
  await page.getByRole("button", { name: "Use QR code", exact: true }).click();
  await expect(page.getByTestId("item-qr-input")).toHaveValue(value);
  await page.getByTestId("item-title-input").fill(`QR Item ${Date.now()}`);
  await page.getByTestId("item-submit-button").click();
  await page.waitForURL(url => /^\/items\/[^/]+$/.test(url.pathname) && url.pathname !== "/items/new");
  const response = await request.get(`/api/v1/items/${page.url().split("/").pop()}`);
  expect(response.ok()).toBe(true);
  expect((await response.json()).originalQrCode).toBe(value);
});

test("AI research reviews sources and saves only selected related suggestions", async ({ page, request }) => {
  await page.route("**/api/v1/items/ai", route => route.fulfill({ json: { ...aiResult, draft: { ...aiResult.draft, title: `AI Camera ${Date.now()}` } } }));
  await page.goto("/items/new?mode=ai");
  await page.getByTestId("item-ai-prompt").fill("Find information about this camera");
  await page.getByRole("button", { name: "Generate draft" }).click();
  await expect(page.getByRole("link", { name: "Official product page" })).toHaveAttribute("href", "https://example.com/camera");
  await page.getByLabel("Create or reuse category: Photography").check();
  await page.getByLabel("Create or reuse author: Camera Maker").check();
  await page.getByLabel("Create or reuse tag: camera", { exact: true }).check();
  await page.getByRole("button", { name: "Apply draft" }).click();
  await expect(page.getByRole("dialog")).toBeHidden();
  await expect(page.getByTestId("item-description-textarea")).toHaveValue(aiResult.draft.description);
  await page.getByTestId("item-submit-button").click();
  await page.waitForURL(url => /^\/items\/[^/]+$/.test(url.pathname) && url.pathname !== "/items/new");
  const response = await request.get(`/api/v1/items/${page.url().split("/").pop()}`);
  expect(response.ok()).toBe(true);
  const item = await response.json();
  expect(item.category.name).toBe("Photography"); expect(item.author.name).toBe("Camera Maker");
  expect(item.tags.map((tag: { title: string }) => tag.title)).toEqual(["camera"]);
});

test("description lookup sends form context and recovers from AI failure", async ({ page }) => {
  await page.goto("/items/new");
  await page.getByTestId("item-title-input").fill("Existing title");
  await page.getByTestId("item-description-textarea").fill("Keep my description");
  await page.getByRole("button", { name: "Search item using AI" }).click();
  let calls = 0;
  await page.route("**/api/v1/items/ai", route => {
    const body = route.request().postDataJSON();
    expect(body.title).toBe("Existing title"); expect(body.webSearch).toBe(false);
    calls++;
    return route.fulfill(calls === 1 ? { status: 502, json: { error: "Research unavailable" } } : { json: aiResult });
  });
  await page.getByLabel("Search the web for item information").uncheck();
  await page.getByRole("button", { name: "Generate draft" }).click();
  await expect(page.getByText("Research unavailable", { exact: true })).toBeVisible();
  await page.getByRole("button", { name: "Generate draft" }).click();
  await expect(page.getByText("Review AI draft", { exact: true })).toBeVisible();
  await page.getByRole("button", { name: "Close", exact: true }).click();
  await expect(page.getByTestId("item-description-textarea")).toHaveValue("Keep my description");
});

test("AI image attachments upload directly to the presigned domain and submit file references", async ({ page }) => {
  let uploaded = false;
  await page.route("https://mock-s3.example.com/upload/**", route => { uploaded = true; return route.fulfill({ status: 200, body: "" }); });
  await page.route("**/api/v1/items/ai", route => {
    expect(uploaded).toBe(true);
    expect(route.request().postDataJSON().images[0]).toMatch(/^file:/);
    return route.fulfill({ json: aiResult });
  });
  await page.goto("/items/new?mode=ai");
  await page.getByLabel("Attach images (up to 5)", { exact: true }).setInputFiles({ name: "camera.png", mimeType: "image/png", buffer: await QRCode.toBuffer("camera") });
  await expect(page.getByText("Attached image 1", { exact: true })).toBeVisible();
  await page.getByRole("button", { name: "Generate draft" }).click();
  await expect(page.getByText("Review AI draft", { exact: true })).toBeVisible();
});
