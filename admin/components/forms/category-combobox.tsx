"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import {
  searchCategories,
  getCategory,
} from "@/lib/actions/category-actions";
import { SEARCH_DEBOUNCE_MS } from "@/lib/config";
import { EntityCombobox } from "./entity-combobox";

interface CategoryComboboxProps {
  value: number | null;
  onChange: (value: number | null) => void;
  disablePortal?: boolean;
}

type CategoryOption = { id: number; name: string };

export function CategoryCombobox({
  value,
  onChange,
  disablePortal,
}: CategoryComboboxProps) {
  const [items, setItems] = useState<CategoryOption[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const debounceRef = useRef<NodeJS.Timeout | null>(null);
  const initialLoadRef = useRef(false);

  // Load initial options on mount and ensure selected value is included
  useEffect(() => {
    if (initialLoadRef.current) return;
    initialLoadRef.current = true;

    const loadInitialData = async () => {
      const results = await searchCategories("", 20);

      // If we have a selected value not in results, fetch it
      if (value && !results.find((r) => r.id === value)) {
        const selected = await getCategory(value);
        if (selected) {
          setItems([{ id: selected.id, name: selected.name }, ...results]);
          return;
        }
      }

      setItems(results);
    };

    loadInitialData();
  }, [value]);

  const handleSearch = useCallback((inputValue: string) => {
    setSearchQuery(inputValue);

    if (debounceRef.current) {
      clearTimeout(debounceRef.current);
    }

    debounceRef.current = setTimeout(async () => {
      setIsSearching(true);
      try {
        const results = await searchCategories(inputValue, 20);
        setItems(results);
      } finally {
        setIsSearching(false);
      }
    }, SEARCH_DEBOUNCE_MS);
  }, []);

  const handleEntityCreated = useCallback(
    (entity: { id: number; name?: string }) => {
      if (entity.name) {
        const newOption: CategoryOption = { id: entity.id, name: entity.name };
        setItems((prev) => [...prev, newOption]);
        onChange(entity.id);
      }
    },
    [onChange]
  );

  return (
    <EntityCombobox<CategoryOption>
      value={value}
      onSelect={onChange}
      items={items}
      isSearching={isSearching}
      hasSearchQuery={searchQuery.length > 0}
      onSearch={handleSearch}
      getItemId={(item) => item.id}
      getItemLabel={(item) => item.name}
      itemRenderer={(item) => item.name}
      label="Category"
      placeholder="Search categories..."
      emptyMessage="No categories found"
      entitySheetType="category"
      onEntityCreated={handleEntityCreated}
      disablePortal={disablePortal}
    />
  );
}
