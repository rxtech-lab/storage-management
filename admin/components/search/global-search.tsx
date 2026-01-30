"use client";

import { useState, useCallback, useEffect } from "react";
import { useRouter } from "next/navigation";
import {
  SearchTrigger,
  SearchCommand,
  type BaseSearchResult,
  type ToolAction,
  type SearchParams,
} from "@rx-lab/dashboard-searching-ui";
import "@rx-lab/dashboard-searching-ui/style.css";
import { Package, Eye, EyeOff, Loader2 } from "lucide-react";
import { getItems, type ItemWithRelations } from "@/lib/actions/item-actions";
import { toolResultRenderers } from "./tool-renderers";

// Extend BaseSearchResult with item-specific metadata
interface ItemSearchResult extends BaseSearchResult<ItemWithRelations> {
  category?: string;
  visibility: "public" | "private";
}

export function GlobalSearch() {
  const [open, setOpen] = useState(false);
  const router = useRouter();

  // Handle keyboard shortcut
  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.key === "k" && (e.metaKey || e.ctrlKey)) {
        e.preventDefault();
        setOpen((prev) => !prev);
      }
    };
    document.addEventListener("keydown", down);
    return () => document.removeEventListener("keydown", down);
  }, []);

  // Search function for quick search mode
  const handleSearch = useCallback(
    async (params: SearchParams): Promise<ItemSearchResult[]> => {
      const { query, limit = 10 } = params;
      if (!query.trim()) return [];

      try {
        const items = await getItems(undefined, { search: query });
        return items.slice(0, limit).map(
          (item): ItemSearchResult => ({
            id: item.id,
            title: item.title,
            snippet: item.description || undefined,
            category: item.category?.name,
            visibility: item.visibility,
            metadata: item,
          }),
        );
      } catch (error) {
        console.error("Search error:", error);
        return [];
      }
    },
    [],
  );

  // Handle result selection
  const handleResultSelect = useCallback(
    (result: ItemSearchResult) => {
      setOpen(false);
      router.push(`/items/${result.id}`);
    },
    [router],
  );

  // Handle tool actions from agent mode
  const handleToolAction = useCallback(
    (action: ToolAction) => {
      if (action.type === "navigate" && typeof action.payload === "string") {
        setOpen(false);
        router.push(action.payload);
      }
    },
    [router],
  );

  // Custom result renderer
  const renderResult = useCallback(
    (result: ItemSearchResult, onSelect: () => void) => (
      <button
        key={result.id}
        onClick={onSelect}
        className="flex items-center gap-3 w-full p-2 rounded-lg hover:bg-muted/50 cursor-pointer"
      >
        <Package className="size-4 text-muted-foreground shrink-0" />
        <div className="flex-1 text-left min-w-0">
          <div className="font-medium truncate">{result.title}</div>
          {result.category && (
            <div className="text-xs text-muted-foreground">
              {result.category}
            </div>
          )}
        </div>
        {result.visibility === "public" ? (
          <Eye className="size-4 text-green-500 shrink-0" />
        ) : (
          <EyeOff className="size-4 text-muted-foreground shrink-0" />
        )}
      </button>
    ),
    [],
  );

  // Custom empty state renderer
  const renderEmpty = useCallback((query: string, hasResults: boolean) => {
    if (hasResults) return null;
    return (
      <div className="py-6 text-center text-sm text-muted-foreground">
        <Package className="h-8 w-8 mx-auto mb-2 opacity-50" />
        <p>No items found for &quot;{query}&quot;</p>
        <p className="text-xs mt-1">Try AI mode for more advanced queries</p>
      </div>
    );
  }, []);

  // Loading state renderer
  const renderLoading = useCallback(
    () => (
      <div className="py-6 text-center text-sm text-muted-foreground">
        <Loader2 className="h-6 w-6 mx-auto mb-2 animate-spin" />
        <p>Searching items...</p>
      </div>
    ),
    [],
  );

  return (
    <>
      <SearchTrigger
        onClick={() => setOpen(true)}
        placeholder="Search items..."
        shortcut={{ key: "K", modifier: "⌘" }}
        className="h-9 w-64"
        variant="outline"
      />

      <SearchCommand
        open={open}
        onOpenChange={setOpen}
        onSearch={handleSearch}
        onResultSelect={handleResultSelect}
        renderResult={renderResult}
        renderEmpty={renderEmpty}
        renderLoading={renderLoading}
        debounceMs={300}
        limit={10}
        placeholder="Search items or ask AI..."
        className="max-w-[80vw] md:min-w-2xl lg:min-w-4xl"
        enableAgentMode
        agentConfig={{
          apiEndpoint: "/api/search-agent",
          toolResultRenderers,
          onToolAction: handleToolAction,
          header: {
            title: "Storage AI Assistant",
            showBackButton: true,
            showClearButton: true,
          },
          input: {
            placeholder: "Ask about your items...",
            placeholderProcessing: "Searching...",
            streamingText: "Thinking...",
          },
        }}
        chatHistoryStorageKey="storage-search-history"
      />
    </>
  );
}
