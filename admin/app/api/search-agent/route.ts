import { streamText, tool, convertToModelMessages, type UIMessage } from "ai";
import { createOpenAI } from "@ai-sdk/openai";
import { z } from "zod";
import { auth } from "@/auth";
import { getItems, type ItemFilters } from "@/lib/actions/item-actions";
import { getCategories } from "@/lib/actions/category-actions";
import { getLocations } from "@/lib/actions/location-actions";
import { getAuthors } from "@/lib/actions/author-actions";
import type {
  DisplayItemsOutput,
  DisplayStatisticsOutput,
  CategoriesOutput,
  LocationsOutput,
  AuthorsOutput,
} from "@/lib/search/types";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const maxDuration = 60;

const systemPrompt = `You are a helpful assistant for a storage management system. You help users find and manage their stored items.

You have access to tools for:
- Searching and displaying items (display_items)
- Showing statistics about the storage system (display_statistics)
- Getting available categories, locations, and authors for filtering

When users ask to find items, ALWAYS use the display_items tool to show the results.
When users ask about statistics or overview, use the display_statistics tool.
When users need to filter by category, location, or author, first use get_categories, get_locations, or get_authors to find the correct ID.

Be concise and helpful. After showing results, briefly summarize what was found.`;

// Define schemas
const displayItemsSchema = z.object({
  search: z.string().optional().describe("Search query for title/description"),
  categoryId: z
    .number()
    .optional()
    .describe(
      "Filter by category ID (use get_categories first to find the ID)",
    ),
  locationId: z
    .number()
    .optional()
    .describe("Filter by location ID (use get_locations first to find the ID)"),
  authorId: z
    .number()
    .optional()
    .describe("Filter by author ID (use get_authors first to find the ID)"),
  limit: z
    .number()
    .optional()
    .default(10)
    .describe("Maximum results to return (default 10)"),
});

const emptySchema = z.object({});

type DisplayItemsInput = z.infer<typeof displayItemsSchema>;

export async function POST(request: Request) {
  const session = await auth();
  if (!session) {
    return new Response("Unauthorized", { status: 401 });
  }

  try {
    const { messages } = await request.json();
    const modelId = process.env.SEARCH_AGENT_MODEL || "gpt-4o-mini";

    // Convert UI messages to model messages format
    const modelMessages = await convertToModelMessages(messages as UIMessage[]);

    const result = streamText({
      model: modelId,
      system: systemPrompt,
      messages: modelMessages,
      tools: {
        // Search and display items
        display_items: tool<DisplayItemsInput, DisplayItemsOutput>({
          description:
            "Search and display items from the storage system. Use this when users want to find, search, list, or view items. Always use this tool to show search results.",
          inputSchema: displayItemsSchema,
          execute: async (params) => {
            const filters: ItemFilters = {};
            if (params.search) filters.search = params.search;
            if (params.categoryId) filters.categoryId = params.categoryId;
            if (params.locationId) filters.locationId = params.locationId;
            if (params.authorId) filters.authorId = params.authorId;

            const items = await getItems(undefined, filters);
            const limitedItems = items.slice(0, params.limit || 10);
            console.log("Search results:", limitedItems, filters);

            return {
              type: "items",
              count: items.length,
              query: params.search,
              items: limitedItems.map((item) => ({
                id: item.id,
                title: item.title,
                description: item.description,
                category: item.category?.name,
                location: item.location?.title,
                author: item.author?.name,
                visibility: item.visibility,
                price: item.price,
                currency: item.currency,
                images: item.images,
              })),
            };
          },
        }),

        // Display statistics
        display_statistics: tool<
          Record<string, never>,
          DisplayStatisticsOutput
        >({
          description:
            "Display statistics and overview about the storage system. Use this when users ask about counts, statistics, or want an overview.",
          inputSchema: emptySchema,
          execute: async () => {
            const [allItems, categoriesList, locationsList, authorsList] =
              await Promise.all([
                getItems(),
                getCategories(),
                getLocations(),
                getAuthors(),
              ]);

            const publicItems = allItems.filter(
              (i) => i.visibility === "public",
            ).length;
            const privateItems = allItems.filter(
              (i) => i.visibility === "private",
            ).length;

            // Count items per category
            const categoryCount = new Map<number, number>();
            for (const item of allItems) {
              if (item.categoryId) {
                categoryCount.set(
                  item.categoryId,
                  (categoryCount.get(item.categoryId) || 0) + 1,
                );
              }
            }

            const categoryBreakdown = categoriesList
              .map((cat) => ({
                id: cat.id,
                name: cat.name,
                count: categoryCount.get(cat.id) || 0,
              }))
              .filter((cat) => cat.count > 0)
              .sort((a, b) => b.count - a.count);

            return {
              type: "statistics",
              totalItems: allItems.length,
              publicItems,
              privateItems,
              totalCategories: categoriesList.length,
              totalLocations: locationsList.length,
              totalAuthors: authorsList.length,
              categoryBreakdown,
            };
          },
        }),

        // Get categories for filtering
        get_categories: tool<Record<string, never>, CategoriesOutput>({
          description:
            "Get all categories available in the system. Use this to find category IDs before filtering items by category.",
          inputSchema: emptySchema,
          execute: async () => {
            const categoriesList = await getCategories();
            return {
              type: "categories",
              categories: categoriesList.map((c) => ({
                id: c.id,
                name: c.name,
              })),
            };
          },
        }),

        // Get locations for filtering
        get_locations: tool<Record<string, never>, LocationsOutput>({
          description:
            "Get all locations available in the system. Use this to find location IDs before filtering items by location.",
          inputSchema: emptySchema,
          execute: async () => {
            const locationsList = await getLocations();
            return {
              type: "locations",
              locations: locationsList.map((l) => ({
                id: l.id,
                title: l.title,
              })),
            };
          },
        }),

        // Get authors for filtering
        get_authors: tool<Record<string, never>, AuthorsOutput>({
          description:
            "Get all authors available in the system. Use this to find author IDs before filtering items by author.",
          inputSchema: emptySchema,
          execute: async () => {
            const authorsList = await getAuthors();
            return {
              type: "authors",
              authors: authorsList.map((a) => ({ id: a.id, name: a.name })),
            };
          },
        }),
      },
    });

    return result.toUIMessageStreamResponse();
  } catch (error) {
    console.error("[search-agent] Error:", error);
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : "Internal server error",
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
}
