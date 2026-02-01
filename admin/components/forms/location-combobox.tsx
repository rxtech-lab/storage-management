"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import {
  searchLocations,
  getLocation,
} from "@/lib/actions/location-actions";
import { SEARCH_DEBOUNCE_MS } from "@/lib/config";
import { EntityCombobox } from "./entity-combobox";

interface LocationComboboxProps {
  value: number | null;
  onChange: (value: number | null) => void;
  disablePortal?: boolean;
}

type LocationOption = { id: number; title: string };

export function LocationCombobox({
  value,
  onChange,
  disablePortal,
}: LocationComboboxProps) {
  const [items, setItems] = useState<LocationOption[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const debounceRef = useRef<NodeJS.Timeout | null>(null);
  const initialLoadRef = useRef(false);

  // Load initial options on mount and ensure selected value is included
  useEffect(() => {
    if (initialLoadRef.current) return;
    initialLoadRef.current = true;

    const loadInitialData = async () => {
      const results = await searchLocations("", 20);

      // If we have a selected value not in results, fetch it
      if (value && !results.find((r) => r.id === value)) {
        const selected = await getLocation(value);
        if (selected) {
          setItems([{ id: selected.id, title: selected.title }, ...results]);
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
        const results = await searchLocations(inputValue, 20);
        setItems(results);
      } finally {
        setIsSearching(false);
      }
    }, SEARCH_DEBOUNCE_MS);
  }, []);

  const handleEntityCreated = useCallback(
    (entity: { id: number; title?: string }) => {
      if (entity.title) {
        const newOption: LocationOption = {
          id: entity.id,
          title: entity.title,
        };
        setItems((prev) => [...prev, newOption]);
        onChange(entity.id);
      }
    },
    [onChange]
  );

  return (
    <EntityCombobox<LocationOption>
      value={value}
      onSelect={onChange}
      items={items}
      isSearching={isSearching}
      hasSearchQuery={searchQuery.length > 0}
      onSearch={handleSearch}
      getItemId={(item) => item.id}
      getItemLabel={(item) => item.title}
      itemRenderer={(item) => item.title}
      label="Location"
      placeholder="Search locations..."
      emptyMessage="No locations found"
      entitySheetType="location"
      onEntityCreated={handleEntityCreated}
      disablePortal={disablePortal}
    />
  );
}
