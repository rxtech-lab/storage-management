"use client";

import { Button } from "@/components/ui/button";
import { Plus } from "lucide-react";
import type { PropertyListProps, PropertyItem } from "./types";
import { PropertyEditor } from "./property-editor";
import { createPropertyItem, generateUniqueKey, moveArrayItem } from "./schema-utils";

export function PropertyList({
  items,
  onChange,
  disabled = false,
}: PropertyListProps) {
  const handleAddProperty = () => {
    const existingKeys = items.map((item) => item.key);
    const newKey = generateUniqueKey(existingKeys);
    const newItem = createPropertyItem(newKey);
    onChange([...items, newItem]);
  };

  const handleUpdateProperty = (index: number, updatedItem: PropertyItem) => {
    const newItems = [...items];
    newItems[index] = updatedItem;
    onChange(newItems);
  };

  const handleDeleteProperty = (index: number) => {
    const newItems = items.filter((_, i) => i !== index);
    onChange(newItems);
  };

  const handleMoveUp = (index: number) => {
    if (index > 0) {
      onChange(moveArrayItem(items, index, index - 1));
    }
  };

  const handleMoveDown = (index: number) => {
    if (index < items.length - 1) {
      onChange(moveArrayItem(items, index, index + 1));
    }
  };

  return (
    <div className="space-y-3">
      {items.length === 0 ? (
        <div className="text-center py-8 text-muted-foreground text-sm border border-dashed rounded-lg" data-testid="property-list-empty">
          No properties defined. Add a property to get started.
        </div>
      ) : (
        <div className="space-y-2">
          {items.map((item, index) => (
            <PropertyEditor
              key={`${item.key}-${index}`}
              item={item}
              index={index}
              onChange={(updated) => handleUpdateProperty(index, updated)}
              onDelete={() => handleDeleteProperty(index)}
              onMoveUp={() => handleMoveUp(index)}
              onMoveDown={() => handleMoveDown(index)}
              isFirst={index === 0}
              isLast={index === items.length - 1}
              disabled={disabled}
            />
          ))}
        </div>
      )}

      <Button
        type="button"
        variant="outline"
        size="sm"
        onClick={handleAddProperty}
        disabled={disabled}
        className="w-full"
        data-testid="property-list-add-button"
      >
        <Plus className="h-4 w-4 mr-2" />
        Add Property
      </Button>
    </div>
  );
}
