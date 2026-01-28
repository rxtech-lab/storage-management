"use client";

import { useRouter, useSearchParams, usePathname } from "next/navigation";
import { useCallback } from "react";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { X, Grid, List, GitBranch } from "lucide-react";
import type { Category, Location, Author } from "@/lib/db";

interface ItemFiltersProps {
  categories: Category[];
  locations: Location[];
  authors: Author[];
  view: "grid" | "list" | "tree";
  onViewChange: (view: "grid" | "list" | "tree") => void;
}

export function ItemFilters({
  categories,
  locations,
  authors,
  view,
  onViewChange,
}: ItemFiltersProps) {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

  const createQueryString = useCallback(
    (name: string, value: string) => {
      const params = new URLSearchParams(searchParams.toString());
      if (value) {
        params.set(name, value);
      } else {
        params.delete(name);
      }
      return params.toString();
    },
    [searchParams]
  );

  const handleFilterChange = (name: string, value: string) => {
    // Treat "__all__" as clearing the filter
    const filterValue = value === "__all__" ? "" : value;
    router.push(`${pathname}?${createQueryString(name, filterValue)}`);
  };

  const clearFilters = () => {
    router.push(pathname);
  };

  const hasFilters =
    searchParams.has("categoryId") ||
    searchParams.has("locationId") ||
    searchParams.has("authorId") ||
    searchParams.has("visibility") ||
    searchParams.has("search");

  return (
    <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
      <div className="flex flex-wrap gap-2">
        <Input
          placeholder="Search items..."
          className="w-[200px]"
          defaultValue={searchParams.get("search") ?? ""}
          onChange={(e) => {
            const value = e.target.value;
            // Debounce search
            const timeoutId = setTimeout(() => {
              handleFilterChange("search", value);
            }, 300);
            return () => clearTimeout(timeoutId);
          }}
        />

        <Select
          value={searchParams.get("categoryId") || "__all__"}
          onValueChange={(value) => handleFilterChange("categoryId", value)}
        >
          <SelectTrigger className="w-[150px]">
            <SelectValue placeholder="Category" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="__all__">All Categories</SelectItem>
            {categories.map((category) => (
              <SelectItem key={category.id} value={category.id.toString()}>
                {category.name}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>

        <Select
          value={searchParams.get("locationId") || "__all__"}
          onValueChange={(value) => handleFilterChange("locationId", value)}
        >
          <SelectTrigger className="w-[150px]">
            <SelectValue placeholder="Location" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="__all__">All Locations</SelectItem>
            {locations.map((location) => (
              <SelectItem key={location.id} value={location.id.toString()}>
                {location.title}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>

        <Select
          value={searchParams.get("authorId") || "__all__"}
          onValueChange={(value) => handleFilterChange("authorId", value)}
        >
          <SelectTrigger className="w-[150px]">
            <SelectValue placeholder="Author" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="__all__">All Authors</SelectItem>
            {authors.map((author) => (
              <SelectItem key={author.id} value={author.id.toString()}>
                {author.name}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>

        <Select
          value={searchParams.get("visibility") || "__all__"}
          onValueChange={(value) => handleFilterChange("visibility", value)}
        >
          <SelectTrigger className="w-[130px]">
            <SelectValue placeholder="Visibility" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="__all__">All</SelectItem>
            <SelectItem value="public">Public</SelectItem>
            <SelectItem value="private">Private</SelectItem>
          </SelectContent>
        </Select>

        {hasFilters && (
          <Button variant="ghost" size="sm" onClick={clearFilters}>
            <X className="h-4 w-4 mr-1" />
            Clear
          </Button>
        )}
      </div>

      <div className="flex gap-1 border rounded-md p-1">
        <Button
          variant={view === "grid" ? "secondary" : "ghost"}
          size="sm"
          onClick={() => onViewChange("grid")}
        >
          <Grid className="h-4 w-4" />
        </Button>
        <Button
          variant={view === "list" ? "secondary" : "ghost"}
          size="sm"
          onClick={() => onViewChange("list")}
        >
          <List className="h-4 w-4" />
        </Button>
        <Button
          variant={view === "tree" ? "secondary" : "ghost"}
          size="sm"
          onClick={() => onViewChange("tree")}
        >
          <GitBranch className="h-4 w-4" />
        </Button>
      </div>
    </div>
  );
}
