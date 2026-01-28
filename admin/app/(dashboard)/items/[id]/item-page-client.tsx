"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { ItemDetailView } from "@/components/items/item-detail-view";
import { ItemDetailEdit } from "@/components/items/item-detail-edit";
import { ItemSections } from "@/components/items/item-sections";
import { ItemActionBar } from "./item-action-bar";
import { BackButton } from "./back-button";
import { HeroMap } from "@/components/maps/hero-map";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import type { ItemWithRelations } from "@/lib/actions/item-actions";
import type { PositionWithSchema } from "@/lib/actions/position-actions";
import type {
  Category,
  Location,
  Author,
  PositionSchema,
  Content,
  ItemWhitelist,
  Location as LocationType,
} from "@/lib/db";

interface ItemPageClientProps {
  item: ItemWithRelations;
  categories: Category[];
  locations: Location[];
  authors: Author[];
  positionSchemas: PositionSchema[];
  positions: PositionWithSchema[];
  contents: Content[];
  whitelist: ItemWhitelist[];
  childItems: ItemWithRelations[];
  location: LocationType | null;
}

export function ItemPageClient({
  item,
  categories,
  locations,
  authors,
  positionSchemas,
  positions,
  contents,
  whitelist,
  childItems,
  location,
}: ItemPageClientProps) {
  const router = useRouter();
  const [isEditOpen, setIsEditOpen] = useState(false);

  const handleUpdate = () => {
    router.refresh();
  };

  const handleSave = () => {
    setIsEditOpen(false);
  };

  return (
    <div className="space-y-6">
      {/* Hero Section with Overlaid Top Bar */}
      <div className="relative -mt-6">
        {/* Sticky Top Bar - overlays on hero map */}
        <div className="sticky -top-5 z-50 flex items-center justify-between px-4 md:px-6 lg:px-8 py-3">
          <BackButton />
          <ItemActionBar
            itemId={item.id}
            itemTitle={item.title}
            onEditClick={() => setIsEditOpen(true)}
          />
        </div>

        {/* Hero Map - pulled up behind the top bar */}
        <div className="-mt-14">
          <HeroMap
            latitude={location?.latitude}
            longitude={location?.longitude}
            title={location?.title}
          />
        </div>
      </div>

      <div className="space-y-8 max-w-4xl">
        {/* Item Info Section - Always visible */}
        <ItemDetailView item={item} />

        {/* Collapsible Sections */}
        <ItemSections
          item={item}
          positions={positions}
          positionSchemas={positionSchemas}
          contents={contents}
          children={childItems}
          whitelist={whitelist}
          onUpdate={handleUpdate}
        />
      </div>

      {/* Edit Sheet */}
      <Sheet open={isEditOpen} onOpenChange={setIsEditOpen}>
        <SheetContent className="sm:max-w-xl overflow-y-auto p-6">
          <SheetHeader>
            <SheetTitle>Edit Item</SheetTitle>
          </SheetHeader>
          <ItemDetailEdit
            item={item}
            categories={categories}
            locations={locations}
            authors={authors}
            onSave={handleSave}
            onCancel={() => setIsEditOpen(false)}
          />
        </SheetContent>
      </Sheet>
    </div>
  );
}
