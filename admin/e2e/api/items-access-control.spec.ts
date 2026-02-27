import { test, expect } from "@playwright/test";

/**
 * Access control tests for GET /api/v1/items/:id
 * Tests public/private visibility and whitelist-based access.
 */
test.describe.serial("Items Access Control", () => {
  const OWNER = "owner-user";
  const OWNER_EMAIL = "owner@example.com";
  const WHITELISTED_USER = "whitelisted-user";
  const WHITELISTED_EMAIL = "allowed@example.com";
  const OTHER_USER = "other-user";
  const OTHER_EMAIL = "other@example.com";

  let publicItemId: number;
  let privateItemId: number;
  let childItemId: number;
  let whitelistEntryId: number;

  test.describe("Setup - Create test data", () => {
    test("should create public item with child", async ({ request }) => {
      // Create public parent item
      const response = await request.post("/api/v1/items", {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
        data: {
          title: "Public Parent Item",
          description: "A public item for access control testing",
          visibility: "publicAccess",
        },
      });
      expect(response.status()).toBe(201);
      const body = await response.json();
      publicItemId = body.id;
      expect(body.visibility).toBe("publicAccess");
    });

    test("should create child for public item", async ({ request }) => {
      const response = await request.post("/api/v1/items", {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
        data: {
          title: "Public Child Item",
          description: "A child of the public item",
          visibility: "publicAccess",
          parentId: publicItemId,
        },
      });
      expect(response.status()).toBe(201);
      childItemId = (await response.json()).id;
    });

    test("should create private item", async ({ request }) => {
      const response = await request.post("/api/v1/items", {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
        data: {
          title: "Private Item",
          description: "A private item for access control testing",
          visibility: "privateAccess",
        },
      });
      expect(response.status()).toBe(201);
      const body = await response.json();
      privateItemId = body.id;
      expect(body.visibility).toBe("privateAccess");
    });
  });

  test.describe("Public item access", () => {
    test("should access public item without auth headers", async ({
      request,
    }) => {
      // Note: In E2E mode, not sending X-Test-User-Id still gives a default session
      // But the public item should be accessible regardless
      const response = await request.get(`/api/v1/items/${publicItemId}`);
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body.id).toBe(publicItemId);
      expect(body.title).toBe("Public Parent Item");
      expect(body.visibility).toBe("publicAccess");
    });

    test("should return children for public item", async ({ request }) => {
      const response = await request.get(`/api/v1/items/${publicItemId}`);
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body.children).toBeInstanceOf(Array);
      expect(body.children.length).toBe(1);
      expect(body.children[0].id).toBe(childItemId);
      expect(body.children[0].title).toBe("Public Child Item");
    });

    test("should return contents array for public item", async ({
      request,
    }) => {
      const response = await request.get(`/api/v1/items/${publicItemId}`);
      expect(response.status()).toBe(200);

      const body = await response.json();
      // Contents should be an array (may be empty if no contents added)
      expect(body.contents).toBeInstanceOf(Array);
    });

    test("should include previewUrl for public item", async ({ request }) => {
      const response = await request.get(`/api/v1/items/${publicItemId}`);
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body.previewUrl).toBeDefined();
      expect(body.previewUrl).toContain(`/preview/item?id=${publicItemId}`);
    });

    test("other user can access public item", async ({ request }) => {
      const response = await request.get(`/api/v1/items/${publicItemId}`, {
        headers: {
          "X-Test-User-Id": OTHER_USER,
          "X-Test-User-Email": OTHER_EMAIL,
        },
      });
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body.id).toBe(publicItemId);
    });
  });

  test.describe("Private item access - Owner", () => {
    test("owner can access their private item", async ({ request }) => {
      const response = await request.get(`/api/v1/items/${privateItemId}`, {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
      });
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body.id).toBe(privateItemId);
      expect(body.title).toBe("Private Item");
      expect(body.visibility).toBe("privateAccess");
    });

    test("owner gets full data including children and contents", async ({
      request,
    }) => {
      const response = await request.get(`/api/v1/items/${privateItemId}`, {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
      });
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body.children).toBeInstanceOf(Array);
      expect(body.contents).toBeInstanceOf(Array);
      expect(body.previewUrl).toBeDefined();
    });
  });

  test.describe("Private item access - Unauthorized", () => {
    test("should return 403 for non-owner user", async ({ request }) => {
      const response = await request.get(`/api/v1/items/${privateItemId}`, {
        headers: {
          "X-Test-User-Id": OTHER_USER,
          "X-Test-User-Email": OTHER_EMAIL,
        },
      });
      expect(response.status()).toBe(403);

      const body = await response.json();
      expect(body.error).toBe("Permission denied");
    });
  });

  test.describe("Whitelist management", () => {
    test("owner can add email to whitelist", async ({ request }) => {
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
        }
      );
      expect(response.status()).toBe(201);

      const body = await response.json();
      expect(body.email).toBe(WHITELISTED_EMAIL.toLowerCase());
      expect(body.itemId).toBe(privateItemId);
      whitelistEntryId = body.id;
    });

    test("owner can view whitelist", async ({ request }) => {
      const response = await request.get(
        `/api/v1/items/${privateItemId}/whitelist`,
        {
          headers: {
            "X-Test-User-Id": OWNER,
            "X-Test-User-Email": OWNER_EMAIL,
          },
        }
      );
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body).toBeInstanceOf(Array);
      expect(body.length).toBeGreaterThanOrEqual(1);
      expect(body.some((e: any) => e.email === WHITELISTED_EMAIL)).toBeTruthy();
    });

    test("non-owner cannot view whitelist", async ({ request }) => {
      const response = await request.get(
        `/api/v1/items/${privateItemId}/whitelist`,
        {
          headers: {
            "X-Test-User-Id": OTHER_USER,
            "X-Test-User-Email": OTHER_EMAIL,
          },
        }
      );
      expect(response.status()).toBe(403);
    });

    test("non-owner cannot add to whitelist", async ({ request }) => {
      const response = await request.post(
        `/api/v1/items/${privateItemId}/whitelist`,
        {
          headers: {
            "X-Test-User-Id": OTHER_USER,
            "X-Test-User-Email": OTHER_EMAIL,
          },
          data: {
            email: "hacker@example.com",
          },
        }
      );
      expect(response.status()).toBe(403);
    });
  });

  test.describe("Private item access - Whitelisted user", () => {
    test("whitelisted user can access private item", async ({ request }) => {
      const response = await request.get(`/api/v1/items/${privateItemId}`, {
        headers: {
          "X-Test-User-Id": WHITELISTED_USER,
          "X-Test-User-Email": WHITELISTED_EMAIL,
        },
      });
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body.id).toBe(privateItemId);
      expect(body.title).toBe("Private Item");
    });

    test("whitelisted user gets full data including children and contents", async ({
      request,
    }) => {
      const response = await request.get(`/api/v1/items/${privateItemId}`, {
        headers: {
          "X-Test-User-Id": WHITELISTED_USER,
          "X-Test-User-Email": WHITELISTED_EMAIL,
        },
      });
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body.children).toBeInstanceOf(Array);
      expect(body.contents).toBeInstanceOf(Array);
      expect(body.previewUrl).toBeDefined();
    });

    test("non-whitelisted user still cannot access private item", async ({
      request,
    }) => {
      const response = await request.get(`/api/v1/items/${privateItemId}`, {
        headers: {
          "X-Test-User-Id": OTHER_USER,
          "X-Test-User-Email": OTHER_EMAIL,
        },
      });
      expect(response.status()).toBe(403);
    });

    test("whitelist is case-insensitive", async ({ request }) => {
      // Try with uppercase email
      const response = await request.get(`/api/v1/items/${privateItemId}`, {
        headers: {
          "X-Test-User-Id": WHITELISTED_USER,
          "X-Test-User-Email": WHITELISTED_EMAIL.toUpperCase(),
        },
      });
      expect(response.status()).toBe(200);
    });
  });

  test.describe("Whitelist removal", () => {
    test("owner can remove email from whitelist", async ({ request }) => {
      const response = await request.delete(
        `/api/v1/items/${privateItemId}/whitelist`,
        {
          headers: {
            "X-Test-User-Id": OWNER,
            "X-Test-User-Email": OWNER_EMAIL,
          },
          data: {
            whitelistId: whitelistEntryId,
          },
        }
      );
      expect(response.status()).toBe(200);
    });

    test("previously whitelisted user cannot access after removal", async ({
      request,
    }) => {
      const response = await request.get(`/api/v1/items/${privateItemId}`, {
        headers: {
          "X-Test-User-Id": WHITELISTED_USER,
          "X-Test-User-Email": WHITELISTED_EMAIL,
        },
      });
      expect(response.status()).toBe(403);
    });
  });

  test.describe("Cleanup", () => {
    test("should delete child item", async ({ request }) => {
      const response = await request.delete(`/api/v1/items/${childItemId}`, {
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

    test("should delete private item", async ({ request }) => {
      const response = await request.delete(`/api/v1/items/${privateItemId}`, {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
      });
      expect(response.status()).toBe(204);
    });
  });
});
