import { NextResponse } from "next/server";

const openApiSpec = {
  openapi: "3.0.3",
  info: {
    title: "Storage Management API",
    description: "REST API for managing storage items",
    version: "1.0.0",
  },
  servers: [
    {
      url: "/api/v1",
      description: "API v1",
    },
  ],
  paths: {
    "/items": {
      get: {
        summary: "List all items",
        tags: ["Items"],
        security: [{ bearerAuth: [] }],
        parameters: [
          { name: "categoryId", in: "query", schema: { type: "integer" } },
          { name: "locationId", in: "query", schema: { type: "integer" } },
          { name: "authorId", in: "query", schema: { type: "integer" } },
          { name: "parentId", in: "query", schema: { type: "string" } },
          { name: "visibility", in: "query", schema: { type: "string", enum: ["public", "private"] } },
          { name: "search", in: "query", schema: { type: "string" } },
        ],
        responses: {
          200: { description: "List of items" },
          401: { description: "Unauthorized" },
        },
      },
      post: {
        summary: "Create a new item",
        tags: ["Items"],
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: { $ref: "#/components/schemas/NewItem" },
            },
          },
        },
        responses: {
          201: { description: "Item created" },
          400: { description: "Bad request" },
          401: { description: "Unauthorized" },
        },
      },
    },
    "/items/{id}": {
      get: {
        summary: "Get item by ID",
        tags: ["Items"],
        security: [{ bearerAuth: [] }],
        parameters: [{ name: "id", in: "path", required: true, schema: { type: "integer" } }],
        responses: {
          200: { description: "Item details" },
          404: { description: "Not found" },
        },
      },
      put: {
        summary: "Update item",
        tags: ["Items"],
        security: [{ bearerAuth: [] }],
        parameters: [{ name: "id", in: "path", required: true, schema: { type: "integer" } }],
        responses: {
          200: { description: "Item updated" },
          404: { description: "Not found" },
        },
      },
      delete: {
        summary: "Delete item",
        tags: ["Items"],
        security: [{ bearerAuth: [] }],
        parameters: [{ name: "id", in: "path", required: true, schema: { type: "integer" } }],
        responses: {
          200: { description: "Item deleted" },
          404: { description: "Not found" },
        },
      },
    },
    "/items/{id}/children": {
      get: {
        summary: "Get item children",
        tags: ["Items"],
        security: [{ bearerAuth: [] }],
        parameters: [{ name: "id", in: "path", required: true, schema: { type: "integer" } }],
        responses: { 200: { description: "List of child items" } },
      },
    },
    "/items/{id}/qr": {
      get: {
        summary: "Get QR code for item",
        tags: ["Items"],
        security: [{ bearerAuth: [] }],
        parameters: [{ name: "id", in: "path", required: true, schema: { type: "integer" } }],
        responses: { 200: { description: "QR code data" } },
      },
    },
    "/categories": {
      get: {
        summary: "List all categories",
        tags: ["Categories"],
        security: [{ bearerAuth: [] }],
        responses: { 200: { description: "List of categories" } },
      },
      post: {
        summary: "Create category",
        tags: ["Categories"],
        security: [{ bearerAuth: [] }],
        responses: { 201: { description: "Category created" } },
      },
    },
    "/locations": {
      get: {
        summary: "List all locations",
        tags: ["Locations"],
        security: [{ bearerAuth: [] }],
        responses: { 200: { description: "List of locations" } },
      },
      post: {
        summary: "Create location",
        tags: ["Locations"],
        security: [{ bearerAuth: [] }],
        responses: { 201: { description: "Location created" } },
      },
    },
    "/authors": {
      get: {
        summary: "List all authors",
        tags: ["Authors"],
        security: [{ bearerAuth: [] }],
        responses: { 200: { description: "List of authors" } },
      },
      post: {
        summary: "Create author",
        tags: ["Authors"],
        security: [{ bearerAuth: [] }],
        responses: { 201: { description: "Author created" } },
      },
    },
    "/position-schemas": {
      get: {
        summary: "List all position schemas",
        tags: ["Position Schemas"],
        security: [{ bearerAuth: [] }],
        responses: { 200: { description: "List of position schemas" } },
      },
      post: {
        summary: "Create position schema",
        tags: ["Position Schemas"],
        security: [{ bearerAuth: [] }],
        responses: { 201: { description: "Position schema created" } },
      },
    },
    "/preview/{id}": {
      get: {
        summary: "Get item preview",
        tags: ["Preview"],
        parameters: [{ name: "id", in: "path", required: true, schema: { type: "integer" } }],
        responses: {
          200: { description: "Item preview data" },
          401: { description: "Authentication required (private item)" },
          403: { description: "Access denied" },
          404: { description: "Not found" },
        },
      },
    },
  },
  components: {
    securitySchemes: {
      bearerAuth: {
        type: "http",
        scheme: "bearer",
      },
    },
    schemas: {
      NewItem: {
        type: "object",
        required: ["title"],
        properties: {
          title: { type: "string" },
          description: { type: "string" },
          categoryId: { type: "integer", nullable: true },
          locationId: { type: "integer", nullable: true },
          authorId: { type: "integer", nullable: true },
          parentId: { type: "integer", nullable: true },
          price: { type: "number", nullable: true },
          visibility: { type: "string", enum: ["public", "private"] },
          images: { type: "array", items: { type: "string" } },
        },
      },
    },
  },
};

export async function GET() {
  return NextResponse.json(openApiSpec);
}
