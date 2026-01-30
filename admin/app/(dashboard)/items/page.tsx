"use client";

import { useState, useEffect } from "react";
import { useSearchParams } from "next/navigation";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Plus } from "lucide-react";
import { ItemFilters } from "@/components/items/item-filters";
import { ItemPreview } from "@/components/items/item-preview";
import { ItemTreeView } from "@/components/items/item-tree-view";
import { getItems, type ItemWithRelations } from "@/lib/actions/item-actions";
import { getCategories } from "@/lib/actions/category-actions";
import { getLocations } from "@/lib/actions/location-actions";
import { getAuthors } from "@/lib/actions/author-actions";
import type { Category, Location, Author } from "@/lib/db";

export default function ItemsPage() {
  const searchParams = useSearchParams();
  const [view, setView] = useState<"grid" | "list" | "tree">("grid");
  const [items, setItems] = useState<ItemWithRelations[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [locations, setLocations] = useState<Location[]>([]);
  const [authors, setAuthors] = useState<Author[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadData() {
      setLoading(true);
      try {
        const filters = {
          categoryId: searchParams.get("categoryId")
            ? parseInt(searchParams.get("categoryId")!)
            : undefined,
          locationId: searchParams.get("locationId")
            ? parseInt(searchParams.get("locationId")!)
            : undefined,
          authorId: searchParams.get("authorId")
            ? parseInt(searchParams.get("authorId")!)
            : undefined,
          visibility: searchParams.get("visibility") as
            | "public"
            | "private"
            | undefined,
          search: searchParams.get("search") || undefined,
        };

        const [itemsData, categoriesData, locationsData, authorsData] =
          await Promise.all([
            getItems(undefined, filters),
            getCategories(),
            getLocations(),
            getAuthors(),
          ]);

        setItems(itemsData);
        setCategories(categoriesData);
        setLocations(locationsData);
        setAuthors(authorsData);
      } catch (error) {
        console.error("Failed to load data:", error);
      } finally {
        setLoading(false);
      }
    }

    loadData();
  }, [searchParams]);

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">Items</h1>
          <p className="text-muted-foreground">Manage your storage items</p>
        </div>
        <Link href="/items/new">
          <Button data-testid="items-new-button">
            <Plus className="h-4 w-4 mr-2" />
            New Item
          </Button>
        </Link>
      </div>

      <ItemFilters
        categories={categories}
        locations={locations}
        authors={authors}
        view={view}
        onViewChange={setView}
      />

      {loading ? (
        <div className="flex items-center justify-center py-12">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" />
        </div>
      ) : items.length === 0 ? (
        <div className="text-center py-12">
          <p className="text-muted-foreground">No items found</p>
          <Link href="/items/new" className="mt-4 inline-block">
            <Button variant="outline">
              <Plus className="h-4 w-4 mr-2" />
              Create your first item
            </Button>
          </Link>
        </div>
      ) : view === "tree" ? (
        <ItemTreeView items={items} />
      ) : view === "grid" ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          {items.map((item) => (
            <ItemPreview key={item.id} item={item} view="grid" />
          ))}
        </div>
      ) : (
        <div className="space-y-2">
          {items.map((item) => (
            <ItemPreview key={item.id} item={item} view="list" />
          ))}
        </div>
      )}
    </div>
  );
}
