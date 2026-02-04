import { test, expect } from "@playwright/test";

test.describe("Apple App Site Association", () => {
  test("GET /.well-known/apple-app-site-association - should return valid JSON", async ({
    request,
  }) => {
    const response = await request.get(
      "/.well-known/apple-app-site-association"
    );

    expect(response.status()).toBe(200);

    const contentType = response.headers()["content-type"];
    expect(contentType).toContain("application/json");

    const body = await response.json();
    expect(body).toBeDefined();
  });

  test("GET /.well-known/apple-app-site-association - should have applinks section", async ({
    request,
  }) => {
    const response = await request.get(
      "/.well-known/apple-app-site-association"
    );

    expect(response.status()).toBe(200);
    const body = await response.json();

    expect(body).toHaveProperty("applinks");
    expect(body.applinks).toHaveProperty("details");
    expect(body.applinks.details).toBeInstanceOf(Array);
    expect(body.applinks.details.length).toBeGreaterThan(0);

    const detail = body.applinks.details[0];
    expect(detail).toHaveProperty("appIDs");
    expect(detail.appIDs).toBeInstanceOf(Array);
    expect(detail).toHaveProperty("components");
    expect(detail.components).toBeInstanceOf(Array);
  });

  test("GET /.well-known/apple-app-site-association - should have appclips section", async ({
    request,
  }) => {
    const response = await request.get(
      "/.well-known/apple-app-site-association"
    );

    expect(response.status()).toBe(200);
    const body = await response.json();

    expect(body).toHaveProperty("appclips");
    expect(body.appclips).toHaveProperty("apps");
    expect(body.appclips.apps).toBeInstanceOf(Array);
    expect(body.appclips.apps.length).toBeGreaterThan(0);
  });

  test("GET /.well-known/apple-app-site-association - should have webcredentials section", async ({
    request,
  }) => {
    const response = await request.get(
      "/.well-known/apple-app-site-association"
    );

    expect(response.status()).toBe(200);
    const body = await response.json();

    expect(body).toHaveProperty("webcredentials");
    expect(body.webcredentials).toHaveProperty("apps");
    expect(body.webcredentials.apps).toBeInstanceOf(Array);
    expect(body.webcredentials.apps.length).toBeGreaterThan(0);
  });

  test("GET /.well-known/apple-app-site-association - should have correct app IDs format", async ({
    request,
  }) => {
    const response = await request.get(
      "/.well-known/apple-app-site-association"
    );

    expect(response.status()).toBe(200);
    const body = await response.json();

    // App IDs should be in format: TEAMID.bundleID
    const appClipId = body.appclips.apps[0];
    const webcredentialsAppId = body.webcredentials.apps[0];

    // Check format: should contain a dot separator (TeamID.bundleID)
    expect(appClipId).toMatch(/^[A-Z0-9]+\..+$/i);
    expect(webcredentialsAppId).toMatch(/^[A-Z0-9]+\..+$/i);

    // App Clip ID should end with .Clip
    expect(appClipId).toMatch(/\.Clip$/);

    // Verify expected mock values in test environment
    expect(appClipId).toBe("TESTTEAMID.com.test.app.Clip");
    expect(webcredentialsAppId).toBe("TESTTEAMID.com.test.app");
  });

  test("GET /.well-known/apple-app-site-association - should have /preview/* path component", async ({
    request,
  }) => {
    const response = await request.get(
      "/.well-known/apple-app-site-association"
    );

    expect(response.status()).toBe(200);
    const body = await response.json();

    const components = body.applinks.details[0].components;
    const previewComponent = components.find(
      (c: { "/": string }) => c["/"] === "/preview/*"
    );

    expect(previewComponent).toBeDefined();
  });
});
