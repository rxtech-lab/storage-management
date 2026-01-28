"use client";

import { useState, useCallback, useEffect } from "react";
import { useRouter } from "next/navigation";
import {
  Command,
  CommandDialog,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from "@/components/ui/command";
import { Button } from "@/components/ui/button";
import { Search, Package, Eye, EyeOff } from "lucide-react";
import { getItems, type ItemWithRelations } from "@/lib/actions/item-actions";

export function GlobalSearch() {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<ItemWithRelations[]>([]);
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  // Handle keyboard shortcut
  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.key === "k" && (e.metaKey || e.ctrlKey)) {
        e.preventDefault();
        setOpen((open) => !open);
      }
    };
    document.addEventListener("keydown", down);
    return () => document.removeEventListener("keydown", down);
  }, []);

  // Search items when query changes
  useEffect(() => {
    if (!query.trim()) {
      setResults([]);
      return;
    }

    const searchItems = async () => {
      setLoading(true);
      try {
        const items = await getItems({ search: query });
        setResults(items.slice(0, 10));
      } catch (error) {
        console.error("Search error:", error);
        setResults([]);
      } finally {
        setLoading(false);
      }
    };

    const timeoutId = setTimeout(searchItems, 300);
    return () => clearTimeout(timeoutId);
  }, [query]);

  const handleSelect = useCallback(
    (itemId: number) => {
      setOpen(false);
      setQuery("");
      router.push(`/items/${itemId}`);
    },
    [router]
  );

  return (
    <>
      <Button
        variant="outline"
        className="relative h-9 w-64 justify-start text-sm text-muted-foreground"
        onClick={() => setOpen(true)}
      >
        <Search className="mr-2 h-4 w-4" />
        Search items...
        <kbd className="pointer-events-none absolute right-2 top-2 hidden h-5 select-none items-center gap-1 rounded border bg-muted px-1.5 font-mono text-[10px] font-medium opacity-100 sm:flex">
          <span className="text-xs">⌘</span>K
        </kbd>
      </Button>

      <CommandDialog open={open} onOpenChange={setOpen}>
        <CommandInput
          placeholder="Search items..."
          value={query}
          onValueChange={setQuery}
        />
        <CommandList>
          {loading && (
            <div className="py-6 text-center text-sm text-muted-foreground">
              Searching...
            </div>
          )}
          {!loading && query && results.length === 0 && (
            <CommandEmpty>No items found.</CommandEmpty>
          )}
          {!loading && results.length > 0 && (
            <CommandGroup heading="Items">
              {results.map((item) => (
                <CommandItem
                  key={item.id}
                  value={item.title}
                  onSelect={() => handleSelect(item.id)}
                  className="cursor-pointer"
                >
                  <Package className="mr-2 h-4 w-4" />
                  <div className="flex-1">
                    <p className="font-medium">{item.title}</p>
                    {item.category && (
                      <p className="text-xs text-muted-foreground">
                        {item.category.name}
                      </p>
                    )}
                  </div>
                  {item.visibility === "public" ? (
                    <Eye className="h-4 w-4 text-green-500" />
                  ) : (
                    <EyeOff className="h-4 w-4 text-muted-foreground" />
                  )}
                </CommandItem>
              ))}
            </CommandGroup>
          )}
          {!loading && !query && (
            <div className="py-6 text-center text-sm text-muted-foreground">
              <Package className="h-8 w-8 mx-auto mb-2 opacity-50" />
              <p>Start typing to search items</p>
            </div>
          )}
        </CommandList>
      </CommandDialog>
    </>
  );
}
