import type { ItemWithRelations } from "@/lib/actions/item-actions";

// Search result type for quick search
export interface ItemSearchResult {
  id: number;
  title: string;
  snippet?: string;
  category?: string;
  visibility: "public" | "private";
  metadata: ItemWithRelations;
}

// Tool output types for AI agent
export interface DisplayItemsOutput {
  type: "items";
  count: number;
  query?: string;
  items: Array<{
    id: number;
    title: string;
    description?: string | null;
    category?: string | null;
    location?: string | null;
    author?: string | null;
    visibility: "public" | "private";
    price?: number | null;
    currency?: string | null;
    images?: string[] | null;
  }>;
}

export interface DisplayStatisticsOutput {
  type: "statistics";
  totalItems: number;
  publicItems: number;
  privateItems: number;
  totalCategories: number;
  totalLocations: number;
  totalAuthors: number;
  categoryBreakdown?: Array<{
    id: number;
    name: string;
    count: number;
  }>;
}

export interface CategoriesOutput {
  type: "categories";
  categories: Array<{ id: number; name: string }>;
}

export interface LocationsOutput {
  type: "locations";
  locations: Array<{ id: number; title: string }>;
}

export interface AuthorsOutput {
  type: "authors";
  authors: Array<{ id: number; name: string }>;
}

export type ToolOutput =
  | DisplayItemsOutput
  | DisplayStatisticsOutput
  | CategoriesOutput
  | LocationsOutput
  | AuthorsOutput;
