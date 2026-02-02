"use client";

import {
  Package,
  Eye,
  EyeOff,
  FolderOpen,
  MapPin,
  User,
  BarChart3,
} from "lucide-react";
import type { ToolResultRendererProps } from "@rx-lab/dashboard-searching-ui";
import type { DisplayItemsOutput, DisplayStatisticsOutput } from "@/lib/search/types";

// Items display renderer
export function ItemsRenderer({ output, onAction }: ToolResultRendererProps) {
  const data = output as DisplayItemsOutput;

  if (!data?.items || data.items.length === 0) {
    return (
      <div className="text-muted-foreground text-sm p-4 text-center">
        No items found
        {data?.query && <span> for &quot;{data.query}&quot;</span>}
      </div>
    );
  }

  return (
    <div className="space-y-2">
      <div className="text-xs text-muted-foreground px-2 flex items-center gap-1">
        <Package className="size-3" />
        Found {data.count} item{data.count !== 1 ? "s" : ""}
        {data.count > data.items.length && ` (showing ${data.items.length})`}
        {data.query && <span className="ml-1">for &quot;{data.query}&quot;</span>}
      </div>
      <div className="grid gap-2">
        {data.items.map((item) => (
          <button
            key={item.id}
            onClick={() =>
              onAction?.({
                type: "navigate",
                payload: `/items/${item.id}`,
              })
            }
            className="flex items-center gap-3 p-3 rounded-lg border hover:bg-muted/50 transition-colors text-left w-full"
          >
            <Package className="size-5 text-muted-foreground shrink-0" />
            <div className="flex-1 min-w-0">
              <div className="font-medium truncate">{item.title}</div>
              <div className="flex items-center gap-2 text-xs text-muted-foreground">
                {item.category && (
                  <span className="flex items-center gap-1">
                    <FolderOpen className="size-3" />
                    {item.category}
                  </span>
                )}
                {item.location && (
                  <span className="flex items-center gap-1">
                    <MapPin className="size-3" />
                    {item.location}
                  </span>
                )}
                {item.author && (
                  <span className="flex items-center gap-1">
                    <User className="size-3" />
                    {item.author}
                  </span>
                )}
              </div>
            </div>
            {item.visibility === "publicAccess" ? (
              <Eye className="size-4 text-green-500 shrink-0" />
            ) : (
              <EyeOff className="size-4 text-muted-foreground shrink-0" />
            )}
          </button>
        ))}
      </div>
    </div>
  );
}

// Statistics display renderer
export function StatisticsRenderer({ output }: ToolResultRendererProps) {
  const data = output as DisplayStatisticsOutput;

  if (!data) {
    return (
      <div className="text-muted-foreground text-sm p-4 text-center">
        Unable to load statistics
      </div>
    );
  }

  const stats = [
    { label: "Total Items", value: data.totalItems, icon: Package },
    { label: "Public", value: data.publicItems, icon: Eye },
    { label: "Private", value: data.privateItems, icon: EyeOff },
    { label: "Categories", value: data.totalCategories, icon: FolderOpen },
    { label: "Locations", value: data.totalLocations, icon: MapPin },
    { label: "Authors", value: data.totalAuthors, icon: User },
  ];

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2 text-xs text-muted-foreground px-2">
        <BarChart3 className="size-3" />
        Storage Overview
      </div>
      <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
        {stats.map((stat) => (
          <div
            key={stat.label}
            className="flex items-center gap-3 p-3 rounded-lg border bg-card"
          >
            <stat.icon className="size-4 text-muted-foreground" />
            <div>
              <div className="text-lg font-semibold">{stat.value}</div>
              <div className="text-xs text-muted-foreground">{stat.label}</div>
            </div>
          </div>
        ))}
      </div>
      {data.categoryBreakdown && data.categoryBreakdown.length > 0 && (
        <div className="space-y-2">
          <div className="text-xs text-muted-foreground px-2">
            Items by Category
          </div>
          <div className="space-y-1">
            {data.categoryBreakdown.slice(0, 5).map((cat) => (
              <div
                key={cat.id}
                className="flex items-center justify-between px-3 py-2 rounded-lg border text-sm"
              >
                <span>{cat.name}</span>
                <span className="text-muted-foreground">{cat.count}</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

// Export all renderers as a map
export const toolResultRenderers = {
  display_items: ItemsRenderer,
  display_statistics: StatisticsRenderer,
};
