"use client";

import { useCallback, useMemo } from "react";
import { Label } from "@/components/ui/label";
import {
  Combobox,
  ComboboxInput,
  ComboboxContent,
  ComboboxList,
  ComboboxItem,
} from "@/components/ui/combobox";
import { Loader2 } from "lucide-react";
import { EntitySheet, EntityType } from "./entity-sheet";

export interface EntityComboboxProps<T> {
  // 1. isSearching - loading state while fetching
  isSearching: boolean;

  // 2. items - array of options to display
  items: T[];

  // 3. itemRenderer - how to render each option in dropdown
  itemRenderer: (item: T) => React.ReactNode;

  // 4. onSelect - callback when item selected (with ID or null)
  value: number | null;
  onSelect: (value: number | null) => void;

  // 5. defaultValue support via value prop + getItemLabel
  getItemId: (item: T) => number;
  getItemLabel: (item: T) => string;

  // 6. selectedValueRenderer - custom label for selected value in input (optional)
  // Falls back to getItemLabel if not provided
  selectedValueRenderer?: (item: T) => string;

  // Search callback - called when input value changes
  onSearch: (query: string) => void;

  // Track if user is actively searching (to hide None option)
  hasSearchQuery: boolean;

  // Labels
  label: string;
  placeholder?: string;
  emptyMessage?: string;
  noneLabel?: string;

  // Optional EntitySheet integration
  entitySheetType?: EntityType;
  onEntityCreated?: (entity: {
    id: number;
    name?: string;
    title?: string;
  }) => void;

  // Disable portal for use inside sheets/dialogs
  disablePortal?: boolean;
}

const NONE_ID = 0;

export function EntityCombobox<T>({
  isSearching,
  items,
  itemRenderer,
  value,
  onSelect,
  getItemId,
  getItemLabel,
  selectedValueRenderer,
  onSearch,
  hasSearchQuery,
  label,
  placeholder = "Search...",
  emptyMessage = "No results found",
  noneLabel = "None",
  entitySheetType,
  onEntityCreated,
  disablePortal = false,
}: EntityComboboxProps<T>) {
  // Find the selected item for display
  const selectedItem = useMemo(
    () => items.find((item) => getItemId(item) === value),
    [items, value, getItemId],
  );

  // Determine the display value for the input
  // Show empty string when no selection (null value), not the noneLabel
  const selectedDisplayValue = useMemo(() => {
    if (selectedItem) {
      return selectedValueRenderer
        ? selectedValueRenderer(selectedItem)
        : getItemLabel(selectedItem);
    }
    return "";
  }, [selectedItem, getItemLabel, selectedValueRenderer]);

  // Handle value change from combobox (receives the label string)
  const handleValueChange = useCallback(
    (newValue: unknown) => {
      const labelValue = newValue as string | null;
      if (!labelValue || labelValue === noneLabel) {
        onSelect(null);
      } else {
        const selected = items.find(
          (item) => getItemLabel(item) === labelValue,
        );
        onSelect(selected ? getItemId(selected) : null);
      }
    },
    [onSelect, items, getItemLabel, getItemId, noneLabel],
  );

  // Only show None option when not searching
  const displayItems = hasSearchQuery ? items : items;
  const showNoneOption = !hasSearchQuery;
  const hasNoResults = !isSearching && items.length === 0 && hasSearchQuery;

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between h-9">
        <Label>{label}</Label>
        {entitySheetType && onEntityCreated && (
          <EntitySheet type={entitySheetType} onCreated={onEntityCreated} />
        )}
      </div>
      <Combobox
        value={selectedDisplayValue}
        onValueChange={handleValueChange}
        onInputValueChange={onSearch}
      >
        <ComboboxInput
          placeholder={placeholder}
          showClear={!!value}
          className="w-full"
        />
        <ComboboxContent disablePortal={disablePortal}>
          {isSearching && (
            <div className="flex items-center justify-center py-2">
              <Loader2 className="h-4 w-4 animate-spin text-muted-foreground" />
            </div>
          )}
          <ComboboxList>
            {showNoneOption && (
              <ComboboxItem key={NONE_ID} value={noneLabel}>
                {noneLabel}
              </ComboboxItem>
            )}
            {displayItems.map((item) => (
              <ComboboxItem key={getItemId(item)} value={getItemLabel(item)}>
                {itemRenderer(item)}
              </ComboboxItem>
            ))}
          </ComboboxList>
          {hasNoResults && (
            <div className="text-muted-foreground py-2 text-center text-sm">
              {emptyMessage}
            </div>
          )}
        </ComboboxContent>
      </Combobox>
    </div>
  );
}
