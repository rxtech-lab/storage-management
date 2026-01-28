"use client";

import { useRouter } from "next/navigation";
import { ItemDetailView } from "@/components/items/item-detail-view";
import { ItemDetailEdit } from "@/components/items/item-detail-edit";
import { ItemSections } from "@/components/items/item-sections";
import type { ItemWithRelations } from "@/lib/actions/item-actions";
import type { PositionWithSchema } from "@/lib/actions/position-actions";
import type { Category, Location, Author, PositionSchema, Content, ItemWhitelist } from "@/lib/db";

interface ItemDetailClientProps {
  item: ItemWithRelations;
  categories: Category[];
  locations: Location[];
  authors: Author[];
  positionSchemas: PositionSchema[];
  positions: PositionWithSchema[];
  contents: Content[];
  whitelist: ItemWhitelist[];
  childItems: ItemWithRelations[];
  isEditing: boolean;
}

export function ItemDetailClient({
  item,
  categories,
  locations,
  authors,
  positionSchemas,
  positions,
  contents,
  whitelist,
  childItems,
  isEditing,
}: ItemDetailClientProps) {
  const router = useRouter();

  const handleUpdate = () => {
    router.refresh();
  };

  const handleExitEdit = () => {
    router.push(`/items/${item.id}`);
  };

  return (
    <div className="space-y-8 max-w-4xl">
      {/* Item Info Section */}
      {isEditing ? (
        <ItemDetailEdit
          item={item}
          categories={categories}
          locations={locations}
          authors={authors}
          onSave={handleExitEdit}
          onCancel={handleExitEdit}
        />
      ) : (
        <ItemDetailView item={item} />
      )}

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
  );
}
