import { createInsertSchema, createSelectSchema } from "drizzle-zod";
import { z } from "zod";
import { items } from "@/lib/db/schema";
import { PaginationQueryParams, PaginationInfo } from "./common";

// Base schemas from Drizzle (for internal validation)
export const ItemSelectSchema = createSelectSchema(items);
const DrizzleItemInsertSchema = createInsertSchema(items).omit({
  id: true,
  userId: true,
  createdAt: true,
  updatedAt: true,
});

// Position data for creating positions with items
const NewPositionDataSchema = z.object({
  positionSchemaId: z.number().int().describe("Position schema ID"),
  data: z.record(z.unknown()).describe("Position data"),
});

// Explicit insert schema for OpenAPI (properly exports)
export const ItemInsertSchema = z.object({
  title: z.string().describe("Item title"),
  description: z.string().nullable().optional().describe("Item description"),
  originalQrCode: z.string().nullable().optional().describe("Original QR code value"),
  categoryId: z.number().int().nullable().optional().describe("Category ID reference"),
  locationId: z.number().int().nullable().optional().describe("Location ID reference"),
  authorId: z.number().int().nullable().optional().describe("Author ID reference"),
  parentId: z.number().int().nullable().optional().describe("Parent item ID for hierarchy"),
  price: z.number().nullable().optional().describe("Item price"),
  currency: z.string().nullable().optional().describe("Currency code (e.g., USD)"),
  visibility: z.enum(["publicAccess", "privateAccess"]).describe("Visibility setting"),
  images: z.array(z.string()).optional().describe("Image file references (file:N format)"),
  positions: z.array(NewPositionDataSchema).optional().describe("Positions to create with the item"),
});

// Explicit update schema for OpenAPI (properly exports)
export const ItemUpdateSchema = z.object({
  title: z.string().optional().describe("Item title"),
  description: z.string().nullable().optional().describe("Item description"),
  originalQrCode: z.string().nullable().optional().describe("Original QR code value"),
  categoryId: z.number().int().nullable().optional().describe("Category ID reference"),
  locationId: z.number().int().nullable().optional().describe("Location ID reference"),
  authorId: z.number().int().nullable().optional().describe("Author ID reference"),
  parentId: z.number().int().nullable().optional().describe("Parent item ID for hierarchy"),
  price: z.number().nullable().optional().describe("Item price"),
  currency: z.string().nullable().optional().describe("Currency code (e.g., USD)"),
  visibility: z.enum(["publicAccess", "privateAccess"]).optional().describe("Visibility setting"),
  images: z.array(z.string()).optional().describe("Image file references (file:N format)"),
  positions: z.array(NewPositionDataSchema).optional().describe("Positions to create with the item"),
});

// Explicit base item schema for OpenAPI (properly exports to OpenAPI spec)
const ItemBaseSchema = z.object({
  id: z.number().int().describe("Unique item identifier"),
  userId: z.string().describe("Owner user ID"),
  title: z.string().describe("Item title"),
  description: z.string().nullable().describe("Item description"),
  originalQrCode: z.string().nullable().describe("Original QR code value"),
  categoryId: z.number().int().nullable().describe("Category ID reference"),
  locationId: z.number().int().nullable().describe("Location ID reference"),
  authorId: z.number().int().nullable().describe("Author ID reference"),
  parentId: z.number().int().nullable().describe("Parent item ID for hierarchy"),
  price: z.number().nullable().describe("Item price"),
  currency: z.string().nullable().describe("Currency code (e.g., USD)"),
  visibility: z.enum(["publicAccess", "privateAccess"]).describe("Visibility setting: publicAccess or privateAccess"),
  createdAt: z.coerce.date().describe("Creation timestamp"),
  updatedAt: z.coerce.date().describe("Last update timestamp"),
});

// Category reference in item response (base object)
export const CategoryRefSchema = z.object({
  id: z.number().int().describe("Category ID"),
  name: z.string().describe("Category name"),
});

// Location reference in item response (base object)
export const LocationRefSchema = z.object({
  id: z.number().int().describe("Location ID"),
  title: z.string().describe("Location title"),
  latitude: z.number().describe("Latitude coordinate"),
  longitude: z.number().describe("Longitude coordinate"),
});

// Author reference in item response (base object)
export const AuthorRefSchema = z.object({
  id: z.number().int().describe("Author ID"),
  name: z.string().describe("Author name"),
});

// Content in item detail response
export const ContentRefSchema = z.object({
  id: z.number().int().describe("Content ID"),
  type: z.enum(["file", "image", "video"]).describe("Content type"),
  data: z.record(z.unknown()).describe("Content data"),
  createdAt: z.coerce.date().describe("Creation timestamp"),
  updatedAt: z.coerce.date().describe("Last update timestamp"),
});

// Position in item detail response
export const PositionRefSchema = z.object({
  id: z.number().int().describe("Position ID"),
  positionSchemaId: z.number().int().describe("Position schema ID"),
  data: z.record(z.unknown()).describe("Position data"),
});

// Extended response with relations and computed fields
export const ItemResponseSchema = ItemBaseSchema.extend({
  previewUrl: z.string().url().describe("Public preview URL for the item"),
  images: z.array(z.string().url()).describe("Signed image URLs"),
  category: CategoryRefSchema.nullable().describe("Associated category"),
  location: LocationRefSchema.nullable().describe("Associated location"),
  author: AuthorRefSchema.nullable().describe("Associated author"),
});

// Item detail response with children, contents, positions
export const ItemDetailResponseSchema = ItemResponseSchema.extend({
  children: z.array(ItemResponseSchema).describe("Child items"),
  contents: z.array(ContentRefSchema).describe("Associated content attachments"),
  positions: z.array(PositionRefSchema).describe("Position data entries"),
});

// Query params for items list
export const ItemsQueryParams = PaginationQueryParams.extend({
  search: z.string().optional().describe("Search query for title/description"),
  categoryId: z.coerce.number().int().optional().describe("Filter by category ID"),
  locationId: z.coerce.number().int().optional().describe("Filter by location ID"),
  authorId: z.coerce.number().int().optional().describe("Filter by author ID"),
  parentId: z
    .union([z.coerce.number().int(), z.literal("null")])
    .optional()
    .describe("Filter by parent ID (use 'null' for root items)"),
  visibility: z
    .enum(["publicAccess", "privateAccess"])
    .optional()
    .describe("Filter by visibility"),
});

// Paginated items response
export const PaginatedItemsResponse = z.object({
  data: z.array(ItemResponseSchema).describe("Array of items"),
  pagination: PaginationInfo,
});

// Set parent request body
export const SetParentRequestSchema = z.object({
  parentId: z
    .number()
    .int()
    .nullable()
    .describe("Parent item ID (null to remove parent)"),
});
