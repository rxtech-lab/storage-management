import { items } from "@/lib/db/schema";
import { createSelectSchema } from "drizzle-zod";
import { z } from "zod";
import { PaginationInfo, PaginationQueryParams } from "./common";
import { TagRefSchema } from "./tags";

// Base schemas from Drizzle (for internal validation)
export const ItemSelectSchema = createSelectSchema(items);

// Position data for creating positions with items
const NewPositionDataSchema = z.object({
  positionSchemaId: z.string().describe("Position schema ID"),
  data: z.record(z.unknown()).describe("Position data"),
});

// Explicit insert schema for OpenAPI (properly exports)
export const ItemInsertSchema = z.object({
  title: z.string().describe("Item title"),
  description: z.string().nullable().optional().describe("Item description"),
  originalQrCode: z
    .string()
    .nullable()
    .optional()
    .describe("Original QR code value"),
  categoryId: z
    .string()
    .nullable()
    .optional()
    .describe("Category ID reference"),
  locationId: z
    .string()
    .nullable()
    .optional()
    .describe("Location ID reference"),
  authorId: z
    .string()
    .nullable()
    .optional()
    .describe("Author ID reference"),
  parentId: z
    .string()
    .nullable()
    .optional()
    .describe("Parent item ID for hierarchy"),
  price: z.number().nullable().optional().describe("Item price"),
  currency: z
    .string()
    .nullable()
    .optional()
    .describe("Currency code (e.g., USD)"),
  visibility: z
    .enum(["publicAccess", "privateAccess"])
    .describe("Visibility setting"),
  itemDate: z.coerce
    .date()
    .nullable()
    .optional()
    .describe("Item date (when different from creation date)"),
  expiresAt: z.coerce
    .date()
    .nullable()
    .optional()
    .describe("Deadline or expiration date"),
  images: z
    .array(z.string())
    .optional()
    .describe("Image file references (file:N format)"),
  positions: z
    .array(NewPositionDataSchema)
    .optional()
    .describe("Positions to create with the item"),
});

// Explicit update schema for OpenAPI (properly exports)
export const ItemUpdateSchema = z.object({
  title: z.string().optional().describe("Item title"),
  description: z.string().nullable().optional().describe("Item description"),
  originalQrCode: z
    .string()
    .nullable()
    .optional()
    .describe("Original QR code value"),
  categoryId: z
    .string()
    .nullable()
    .optional()
    .describe("Category ID reference"),
  locationId: z
    .string()
    .nullable()
    .optional()
    .describe("Location ID reference"),
  authorId: z
    .string()
    .nullable()
    .optional()
    .describe("Author ID reference"),
  parentId: z
    .string()
    .nullable()
    .optional()
    .describe("Parent item ID for hierarchy"),
  price: z.number().nullable().optional().describe("Item price"),
  currency: z
    .string()
    .nullable()
    .optional()
    .describe("Currency code (e.g., USD)"),
  visibility: z
    .enum(["publicAccess", "privateAccess"])
    .optional()
    .describe("Visibility setting"),
  itemDate: z.coerce
    .date()
    .nullable()
    .optional()
    .describe("Item date (when different from creation date)"),
  expiresAt: z.coerce
    .date()
    .nullable()
    .optional()
    .describe("Deadline or expiration date"),
  images: z
    .array(z.string())
    .optional()
    .describe("Image file references (file:N format)"),
  positions: z
    .array(NewPositionDataSchema)
    .optional()
    .describe("Positions to create with the item"),
});

// Category reference in item response (base object)
export const CategoryRefSchema = z.object({
  id: z.string().describe("Category ID"),
  name: z.string().describe("Category name"),
});

// Location reference in item response (base object)
export const LocationRefSchema = z.object({
  id: z.string().describe("Location ID"),
  title: z.string().describe("Location title"),
  latitude: z.number().describe("Latitude coordinate"),
  longitude: z.number().describe("Longitude coordinate"),
});

// Author reference in item response (base object)
export const AuthorRefSchema = z.object({
  id: z.string().describe("Author ID"),
  name: z.string().describe("Author name"),
});

// Content in item detail response
export const ContentRefSchema = z.object({
  id: z.string().describe("Content ID"),
  type: z.enum(["file", "image", "video"]).describe("Content type"),
  data: z.record(z.unknown()).describe("Content data"),
  createdAt: z.coerce.date().describe("Creation timestamp"),
  updatedAt: z.coerce.date().describe("Last update timestamp"),
});

// Position in item detail response
export const PositionRefSchema = z.object({
  id: z.string().describe("Position ID"),
  positionSchemaId: z.string().describe("Position schema ID"),
  data: z.record(z.unknown()).describe("Position data"),
});

// Stock history entry in item detail response
export const StockHistoryRefSchema = z.object({
  id: z.string().describe("Stock history entry ID"),
  quantity: z.number().int().describe("Quantity change"),
  note: z.string().nullable().describe("Optional note"),
  createdAt: z.coerce.date().describe("Creation timestamp"),
});

// Signed image with ID and URL
export const SignedImageSchema = z.object({
  id: z.string().describe("File ID"),
  url: z.string().url().describe("Signed image URL"),
});

// Extended response with relations and computed fields (defined inline to avoid extend issues with generator)
export const ItemResponseSchema = z.object({
  id: z.string().describe("Unique item identifier"),
  userId: z.string().describe("Owner user ID"),
  title: z.string().describe("Item title"),
  description: z.string().nullable().describe("Item description"),
  originalQrCode: z.string().nullable().describe("Original QR code value"),
  categoryId: z.string().nullable().describe("Category ID reference"),
  locationId: z.string().nullable().describe("Location ID reference"),
  authorId: z.string().nullable().describe("Author ID reference"),
  parentId: z
    .string()
    .nullable()
    .describe("Parent item ID for hierarchy"),
  price: z.number().nullable().describe("Item price"),
  currency: z.string().nullable().describe("Currency code (e.g., USD)"),
  visibility: z
    .enum(["publicAccess", "privateAccess"])
    .describe("Visibility setting: publicAccess or privateAccess"),
  createdAt: z.coerce.date().describe("Creation timestamp"),
  updatedAt: z.coerce.date().describe("Last update timestamp"),
  itemDate: z.coerce.date().nullable().describe("Item date (when different from creation date)"),
  expiresAt: z.coerce.date().nullable().describe("Deadline or expiration date"),
  previewUrl: z.string().url().describe("Public preview URL for the item"),
  images: z.array(SignedImageSchema).describe("Signed images with IDs and URLs"),
  category: CategoryRefSchema.nullable().describe("Associated category"),
  location: LocationRefSchema.nullable().describe("Associated location"),
  author: AuthorRefSchema.nullable().describe("Associated author"),
});

// Item detail response with children, contents, positions (defined inline to avoid extend issues with generator)
export const ItemDetailResponseSchema = z.object({
  id: z.string().describe("Unique item identifier"),
  userId: z.string().describe("Owner user ID"),
  title: z.string().describe("Item title"),
  description: z.string().nullable().describe("Item description"),
  originalQrCode: z.string().nullable().describe("Original QR code value"),
  categoryId: z.string().nullable().describe("Category ID reference"),
  locationId: z.string().nullable().describe("Location ID reference"),
  authorId: z.string().nullable().describe("Author ID reference"),
  parentId: z
    .string()
    .nullable()
    .describe("Parent item ID for hierarchy"),
  price: z.number().nullable().describe("Item price"),
  currency: z.string().nullable().describe("Currency code (e.g., USD)"),
  visibility: z
    .enum(["publicAccess", "privateAccess"])
    .describe("Visibility setting: publicAccess or privateAccess"),
  createdAt: z.coerce.date().describe("Creation timestamp"),
  updatedAt: z.coerce.date().describe("Last update timestamp"),
  itemDate: z.coerce.date().nullable().describe("Item date (when different from creation date)"),
  expiresAt: z.coerce.date().nullable().describe("Deadline or expiration date"),
  previewUrl: z.string().url().describe("Public preview URL for the item"),
  images: z.array(SignedImageSchema).describe("Signed images with IDs and URLs"),
  category: CategoryRefSchema.nullable().describe("Associated category"),
  location: LocationRefSchema.nullable().describe("Associated location"),
  author: AuthorRefSchema.nullable().describe("Associated author"),
  children: z.array(ItemResponseSchema).describe("Child items"),
  contents: z
    .array(ContentRefSchema)
    .describe("Associated content attachments (limited to first 10)"),
  totalContents: z
    .number()
    .int()
    .describe("Total number of content attachments for this item"),
  positions: z.array(PositionRefSchema).describe("Position data entries"),
  quantity: z.number().int().describe("Computed current stock quantity"),
  stockHistory: z.array(StockHistoryRefSchema).describe("Stock history entries"),
  tags: z.array(TagRefSchema).describe("Tags associated with this item"),
});

// Comparison operator for date filters
const ComparisonOpSchema = z.enum(["gt", "gte", "lt", "lte", "eq"]);

// Query params for items list
export const ItemsQueryParams = PaginationQueryParams.extend({
  search: z.string().optional().describe("Search query for title/description"),
  categoryId: z.string().optional().describe("Filter by category ID"),
  locationId: z.string().optional().describe("Filter by location ID"),
  authorId: z.string().optional().describe("Filter by author ID"),
  parentId: z
    .union([z.string(), z.literal("null")])
    .optional()
    .describe("Filter by parent ID (use 'null' for root items)"),
  visibility: z
    .enum(["publicAccess", "privateAccess"])
    .optional()
    .describe("Filter by visibility"),
  sortBy: z
    .enum(["createdAt", "lastUsedAsParent"])
    .optional()
    .describe("Sort field (default: createdAt)"),
  tagIds: z
    .string()
    .optional()
    .describe("Comma-separated tag IDs to filter by (AND logic)"),
  itemDateOp: ComparisonOpSchema.optional().describe(
    "Comparison operator for item date filter"
  ),
  itemDateValue: z
    .string()
    .optional()
    .describe("ISO date string for item date filter"),
  expiresAtOp: ComparisonOpSchema.optional().describe(
    "Comparison operator for deadline filter"
  ),
  expiresAtValue: z
    .string()
    .optional()
    .describe("ISO date string for deadline filter"),
});

// Paginated items response
export const PaginatedItemsResponse = z.object({
  data: z.array(ItemResponseSchema).describe("Array of items"),
  pagination: PaginationInfo,
});

// Set parent request body
export const SetParentRequestSchema = z.object({
  parentId: z
    .string()
    .nullable()
    .describe("Parent item ID (null to remove parent)"),
});
