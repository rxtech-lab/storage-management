"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { Label } from "@/components/ui/label";
import {
  Combobox,
  ComboboxInput,
  ComboboxContent,
  ComboboxList,
  ComboboxItem,
  ComboboxEmpty,
} from "@/components/ui/combobox";
import { Loader2 } from "lucide-react";
import { searchItems } from "@/lib/actions/item-actions";

interface ParentItemComboboxProps {
  value: number | null;
  onChange: (value: number | null) => void;
  excludeId?: number;
}

type ItemOption = { id: number; title: string };

const NONE_OPTION: ItemOption = { id: 0, title: "None (Root Item)" };

export function ParentItemCombobox({
  value,
  onChange,
  excludeId,
}: ParentItemComboboxProps) {
  const [options, setOptions] = useState<ItemOption[]>([NONE_OPTION]);
  const [loading, setLoading] = useState(false);
  const debounceRef = useRef<NodeJS.Timeout | null>(null);

  // Load initial options on mount
  useEffect(() => {
    searchItems("", excludeId, 20).then((results) => {
      setOptions([NONE_OPTION, ...results]);
    });
  }, [excludeId]);

  const handleInputChange = useCallback(
    (_value: unknown, event: React.ChangeEvent<HTMLInputElement>) => {
      const query = event.target.value;

      if (debounceRef.current) {
        clearTimeout(debounceRef.current);
      }

      debounceRef.current = setTimeout(async () => {
        setLoading(true);
        try {
          const results = await searchItems(query, excludeId, 20);
          setOptions([NONE_OPTION, ...results]);
        } finally {
          setLoading(false);
        }
      }, 300);
    },
    [excludeId]
  );

  const handleValueChange = useCallback(
    (newValue: unknown) => {
      const title = newValue as string | null;
      if (!title || title === NONE_OPTION.title) {
        onChange(null);
      } else {
        const selected = options.find((opt) => opt.title === title);
        onChange(selected ? selected.id : null);
      }
    },
    [onChange, options]
  );

  const selectedTitle = options.find((opt) => opt.id === (value ?? 0))?.title ?? NONE_OPTION.title;

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between h-9">
        <Label>Parent Item</Label>
      </div>
      <Combobox
        value={selectedTitle}
        onValueChange={handleValueChange}
        onInputValueChange={handleInputChange}
      >
        <ComboboxInput
          placeholder="Search items..."
          showClear={!!value}
          className="w-full"
        />
        <ComboboxContent>
          {loading && (
            <div className="flex items-center justify-center py-2">
              <Loader2 className="h-4 w-4 animate-spin text-muted-foreground" />
            </div>
          )}
          <ComboboxList>
            {options.map((item) => (
              <ComboboxItem key={item.id} value={item.title}>
                {item.title}
              </ComboboxItem>
            ))}
          </ComboboxList>
          <ComboboxEmpty>No items found</ComboboxEmpty>
        </ComboboxContent>
      </Combobox>
    </div>
  );
}
