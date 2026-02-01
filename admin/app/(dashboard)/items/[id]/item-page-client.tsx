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
  PositionSchema,
  Content,
  ItemWhitelist,
} from "@/lib/db";

interface ItemPageClientProps {
  item: ItemWithRelations;
  positionSchemas: PositionSchema[];
  positions: PositionWithSchema[];
  contents: Content[];
  whitelist: ItemWhitelist[];
  childItems: ItemWithRelations[];
}

export function ItemPageClient({
  item,
  positionSchemas,
  positions,
  contents,
  whitelist,
  childItems,
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
    <div>
      {/* Sticky Top Bar */}
      <div className="sticky top-0 z-50 -mt-6 -mx-4 md:-mx-6 lg:-mx-8 px-4 md:px-6 lg:px-8 pb-3 flex items-center justify-between">
        <BackButton />
        <ItemActionBar
          itemId={item.id}
          itemTitle={item.title}
          onEditClick={() => setIsEditOpen(true)}
        />
      </div>

      {/* Hero Map */}
      <div className="-mt-14">
        <HeroMap
          latitude={item.location?.latitude ?? undefined}
          longitude={item.location?.longitude ?? undefined}
          title={item.location?.title ?? undefined}
        />
      </div>

      <div className="space-y-8 max-w-4xl mt-6">
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
            onSave={handleSave}
            onCancel={() => setIsEditOpen(false)}
          />
        </SheetContent>
      </Sheet>
    </div>
  );
}
