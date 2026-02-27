import { test, expect } from "@playwright/test";

/**
 * E2E tests for POST /api/v1/qrcode/scan endpoint
 * Tests QR code scanning with preview URLs and raw QR codes,
 * including permission checks for public and private items.
 */
test.describe.serial("QR Code Scan API", () => {
  const OWNER = "qr-owner-user";
  const OWNER_EMAIL = "qr-owner@example.com";
  const OTHER_USER = "qr-other-user";
  const OTHER_EMAIL = "qr-other@example.com";
  const WHITELISTED_USER = "qr-whitelisted-user";
  const WHITELISTED_EMAIL = "qr-whitelisted@example.com";

  let publicItemId: number;
  let privateItemId: number;
  let rawQrPublicItemId: number;
  let rawQrPrivateItemId: number;

  const RAW_QR_CODE_PUBLIC = "RAW-QR-PUBLIC-12345";
  const RAW_QR_CODE_PRIVATE = "RAW-QR-PRIVATE-67890";

  test.describe("Setup - Create test data", () => {
    test("should create public item", async ({ request }) => {
      const response = await request.post("/api/v1/items", {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
        data: {
          title: "QR Test Public Item",
          description: "A public item for QR code testing",
          visibility: "publicAccess",
        },
      });
      expect(response.status()).toBe(201);
      const body = await response.json();
      publicItemId = body.id;
      expect(body.visibility).toBe("publicAccess");
    });

    test("should create private item", async ({ request }) => {
      const response = await request.post("/api/v1/items", {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
        data: {
          title: "QR Test Private Item",
          description: "A private item for QR code testing",
          visibility: "privateAccess",
        },
      });
      expect(response.status()).toBe(201);
      const body = await response.json();
      privateItemId = body.id;
      expect(body.visibility).toBe("privateAccess");
    });

    test("should create public item with raw QR code", async ({ request }) => {
      const response = await request.post("/api/v1/items", {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
        data: {
          title: "QR Test Raw Public Item",
          description: "A public item with raw QR code",
          visibility: "publicAccess",
          originalQrCode: RAW_QR_CODE_PUBLIC,
        },
      });
      expect(response.status()).toBe(201);
      const body = await response.json();
      rawQrPublicItemId = body.id;
      expect(body.originalQrCode).toBe(RAW_QR_CODE_PUBLIC);
    });

    test("should create private item with raw QR code", async ({ request }) => {
      const response = await request.post("/api/v1/items", {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
        data: {
          title: "QR Test Raw Private Item",
          description: "A private item with raw QR code",
          visibility: "privateAccess",
          originalQrCode: RAW_QR_CODE_PRIVATE,
        },
      });
      expect(response.status()).toBe(201);
      const body = await response.json();
      rawQrPrivateItemId = body.id;
      expect(body.originalQrCode).toBe(RAW_QR_CODE_PRIVATE);
    });
  });

  test.describe("Preview URL QR codes - Public items", () => {
    test("should resolve preview URL for public item (any user)", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OTHER_USER,
          "X-Test-User-Email": OTHER_EMAIL,
        },
        data: {
          qrcontent: `preview/item/${publicItemId}`,
        },
      });
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body.type).toBe("item");
      expect(body.url).toContain(`/api/v1/items/${publicItemId}`);
    });

    test("should resolve full preview URL for public item", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OTHER_USER,
          "X-Test-User-Email": OTHER_EMAIL,
        },
        data: {
          qrcontent: `https://storage.rxlab.app/preview/item/${publicItemId}`,
        },
      });
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body.type).toBe("item");
      expect(body.url).toContain(`/api/v1/items/${publicItemId}`);
    });

    test("should resolve preview URL with leading slash", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OTHER_USER,
          "X-Test-User-Email": OTHER_EMAIL,
        },
        data: {
          qrcontent: `/preview/item/${publicItemId}`,
        },
      });
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body.type).toBe("item");
      expect(body.url).toContain(`/api/v1/items/${publicItemId}`);
    });

    test("should resolve query param format for public item", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OTHER_USER,
          "X-Test-User-Email": OTHER_EMAIL,
        },
        data: {
          qrcontent: `preview/item?id=${publicItemId}`,
        },
      });
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body.type).toBe("item");
      expect(body.url).toContain(`/api/v1/items/${publicItemId}`);
    });

    test("should resolve full URL with query param format", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OTHER_USER,
          "X-Test-User-Email": OTHER_EMAIL,
        },
        data: {
          qrcontent: `https://storage.rxlab.app/preview/item?id=${publicItemId}`,
        },
      });
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body.type).toBe("item");
      expect(body.url).toContain(`/api/v1/items/${publicItemId}`);
    });

    test("should resolve query param format with leading slash", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OTHER_USER,
          "X-Test-User-Email": OTHER_EMAIL,
        },
        data: {
          qrcontent: `/preview/item?id=${publicItemId}`,
        },
      });
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body.type).toBe("item");
      expect(body.url).toContain(`/api/v1/items/${publicItemId}`);
    });
  });

  test.describe("Preview URL QR codes - Private items", () => {
    test("should resolve preview URL for private item as owner", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
        data: {
          qrcontent: `preview/item/${privateItemId}`,
        },
      });
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body.type).toBe("item");
      expect(body.url).toContain(`/api/v1/items/${privateItemId}`);
    });

    test("should return 403 for private item as other user", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OTHER_USER,
          "X-Test-User-Email": OTHER_EMAIL,
        },
        data: {
          qrcontent: `preview/item/${privateItemId}`,
        },
      });
      expect(response.status()).toBe(403);

      const body = await response.json();
      expect(body.error).toBe("Permission denied");
    });
  });

  test.describe("Preview URL QR codes - Whitelist access", () => {
    test("should add user to whitelist", async ({ request }) => {
      const response = await request.post(
        `/api/v1/items/${privateItemId}/whitelist`,
        {
          headers: {
            "X-Test-User-Id": OWNER,
            "X-Test-User-Email": OWNER_EMAIL,
          },
          data: {
            email: WHITELISTED_EMAIL,
          },
        },
      );
      expect(response.status()).toBe(201);
    });

    test("should resolve preview URL for private item as whitelisted user", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": WHITELISTED_USER,
          "X-Test-User-Email": WHITELISTED_EMAIL,
        },
        data: {
          qrcontent: `preview/item/${privateItemId}`,
        },
      });
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body.type).toBe("item");
      expect(body.url).toContain(`/api/v1/items/${privateItemId}`);
    });
  });

  test.describe("Raw QR codes - Public items", () => {
    test("should resolve raw QR code for public item (any user)", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OTHER_USER,
          "X-Test-User-Email": OTHER_EMAIL,
        },
        data: {
          qrcontent: RAW_QR_CODE_PUBLIC,
        },
      });
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body.type).toBe("item");
      expect(body.url).toContain(`/api/v1/items/${rawQrPublicItemId}`);
    });
  });

  test.describe("Raw QR codes - Private items", () => {
    test("should resolve raw QR code for private item as owner", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
        data: {
          qrcontent: RAW_QR_CODE_PRIVATE,
        },
      });
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body.type).toBe("item");
      expect(body.url).toContain(`/api/v1/items/${rawQrPrivateItemId}`);
    });

    test("should return 403 for raw QR code of private item as other user", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OTHER_USER,
          "X-Test-User-Email": OTHER_EMAIL,
        },
        data: {
          qrcontent: RAW_QR_CODE_PRIVATE,
        },
      });
      expect(response.status()).toBe(403);

      const body = await response.json();
      expect(body.error).toBe("Permission denied");
    });
  });

  test.describe("Invalid QR codes", () => {
    test("should return 400 for random string", async ({ request }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
        data: {
          qrcontent: "random-invalid-qr-code-xyz",
        },
      });
      expect(response.status()).toBe(400);

      const body = await response.json();
      expect(body.error).toBe("Invalid QR code");
    });

    test("should return 400 for empty string", async ({ request }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
        data: {
          qrcontent: "",
        },
      });
      expect(response.status()).toBe(400);

      const body = await response.json();
      expect(body.error).toBe("Invalid request body");
    });

    test("should return 400 for non-existent item ID in preview URL", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
        data: {
          qrcontent: "preview/item/999999",
        },
      });
      expect(response.status()).toBe(400);

      const body = await response.json();
      expect(body.error).toBe("Invalid QR code");
    });

    test("should return 400 for non-existent item ID in query param format", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
        data: {
          qrcontent: "preview/item?id=999999",
        },
      });
      expect(response.status()).toBe(400);

      const body = await response.json();
      expect(body.error).toBe("Invalid QR code");
    });

    test("should return 400 for missing qrcontent field", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
        data: {},
      });
      expect(response.status()).toBe(400);

      const body = await response.json();
      expect(body.error).toBe("Invalid request body");
    });
  });

  test.describe("Cleanup", () => {
    test("should delete raw QR private item", async ({ request }) => {
      const response = await request.delete(
        `/api/v1/items/${rawQrPrivateItemId}`,
        {
          headers: {
            "X-Test-User-Id": OWNER,
            "X-Test-User-Email": OWNER_EMAIL,
          },
        },
      );
      expect(response.status()).toBe(204);
    });

    test("should delete raw QR public item", async ({ request }) => {
      const response = await request.delete(
        `/api/v1/items/${rawQrPublicItemId}`,
        {
          headers: {
            "X-Test-User-Id": OWNER,
            "X-Test-User-Email": OWNER_EMAIL,
          },
        },
      );
      expect(response.status()).toBe(204);
    });

    test("should delete private item", async ({ request }) => {
      const response = await request.delete(`/api/v1/items/${privateItemId}`, {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
      });
      expect(response.status()).toBe(204);
    });

    test("should delete public item", async ({ request }) => {
      const response = await request.delete(`/api/v1/items/${publicItemId}`, {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
      });
      expect(response.status()).toBe(204);
    });
  });
});
