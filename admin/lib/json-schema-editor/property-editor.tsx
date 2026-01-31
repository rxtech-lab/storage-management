"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  ChevronDown,
  ChevronUp,
  Trash2,
  ArrowUp,
  ArrowDown,
} from "lucide-react";
import { cn } from "@/lib/utils";
import type { PropertyEditorProps, PropertyType, SchemaProperty } from "./types";
import { PROPERTY_TYPES } from "./types";
import { validatePropertyKey } from "./schema-utils";

export function PropertyEditor({
  item,
  index,
  onChange,
  onDelete,
  onMoveUp,
  onMoveDown,
  isFirst = false,
  isLast = false,
  disabled = false,
}: PropertyEditorProps) {
  const [isExpanded, setIsExpanded] = useState(true);
  const [keyError, setKeyError] = useState<string | undefined>();

  const handleKeyChange = (newKey: string) => {
    const validation = validatePropertyKey(newKey);
    setKeyError(validation.error);
    onChange({ ...item, key: newKey });
  };

  const handleTypeChange = (newType: PropertyType) => {
    const newProperty: SchemaProperty = {
      ...item.property,
      type: newType,
    };

    // Clear type-specific fields when type changes
    if (newType !== "string" && newType !== "number") {
      delete newProperty.enum;
    }
    if (newType !== "array") {
      delete newProperty.items;
    }

    onChange({ ...item, property: newProperty });
  };

  const handlePropertyChange = (updates: Partial<SchemaProperty>) => {
    onChange({
      ...item,
      property: { ...item.property, ...updates },
    });
  };

  const handleRequiredChange = (checked: boolean) => {
    onChange({ ...item, isRequired: checked });
  };

  const handleEnumChange = (enumString: string) => {
    if (!enumString.trim()) {
      const { enum: _, ...rest } = item.property;
      handlePropertyChange(rest);
      return;
    }

    const enumValues = enumString
      .split(",")
      .map((v) => v.trim())
      .filter((v) => v !== "");

    // Convert to numbers if the type is number/integer
    const parsedValues =
      item.property.type === "number" || item.property.type === "integer"
        ? enumValues.map((v) => {
            const num = Number(v);
            return isNaN(num) ? v : num;
          })
        : enumValues;

    handlePropertyChange({ enum: parsedValues });
  };

  const getEnumString = (): string => {
    if (!item.property.enum) return "";
    return item.property.enum.join(", ");
  };

  return (
    <div className="border rounded-lg overflow-hidden">
      {/* Header */}
      <div
        className={cn(
          "flex items-center justify-between px-3 py-2 bg-muted/50",
          disabled && "opacity-50"
        )}
      >
        <button
          type="button"
          onClick={() => setIsExpanded(!isExpanded)}
          className="flex items-center gap-2 text-sm font-medium hover:text-foreground/80"
          disabled={disabled}
        >
          {isExpanded ? (
            <ChevronUp className="h-4 w-4" />
          ) : (
            <ChevronDown className="h-4 w-4" />
          )}
          <span>{item.key || "New Property"}</span>
          {item.isRequired && (
            <span className="text-xs text-destructive">*</span>
          )}
        </button>

        <div className="flex items-center gap-1">
          {onMoveUp && (
            <Button
              type="button"
              variant="ghost"
              size="sm"
              onClick={onMoveUp}
              disabled={disabled || isFirst}
              className="h-7 w-7 p-0"
            >
              <ArrowUp className="h-3.5 w-3.5" />
            </Button>
          )}
          {onMoveDown && (
            <Button
              type="button"
              variant="ghost"
              size="sm"
              onClick={onMoveDown}
              disabled={disabled || isLast}
              className="h-7 w-7 p-0"
            >
              <ArrowDown className="h-3.5 w-3.5" />
            </Button>
          )}
          <Button
            type="button"
            variant="ghost"
            size="sm"
            onClick={onDelete}
            disabled={disabled}
            className="h-7 w-7 p-0 text-destructive hover:text-destructive"
            data-testid={`property-delete-button-${index}`}
          >
            <Trash2 className="h-3.5 w-3.5" />
          </Button>
        </div>
      </div>

      {/* Content */}
      {isExpanded && (
        <div className="p-3 space-y-3">
          {/* Row 1: Key and Type */}
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <Label htmlFor={`key-${item.key}`} className="text-xs">
                Property Name
              </Label>
              <Input
                id={`key-${item.key}`}
                value={item.key}
                onChange={(e) => handleKeyChange(e.target.value)}
                placeholder="property_name"
                disabled={disabled}
                className={cn("h-8", keyError && "border-destructive")}
                data-testid={`property-name-input-${index}`}
              />
              {keyError && (
                <p className="text-xs text-destructive">{keyError}</p>
              )}
            </div>

            <div className="space-y-1.5">
              <Label htmlFor={`type-${item.key}`} className="text-xs">
                Type
              </Label>
              <Select
                value={item.property.type}
                onValueChange={(v) => handleTypeChange(v as PropertyType)}
                disabled={disabled}
              >
                <SelectTrigger id={`type-${item.key}`} className="h-8 w-full" data-testid={`property-type-select-${index}`}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {PROPERTY_TYPES.map((type) => (
                    <SelectItem key={type.value} value={type.value}>
                      {type.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          {/* Row 2: Title and Required */}
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <Label htmlFor={`title-${item.key}`} className="text-xs">
                Title
              </Label>
              <Input
                id={`title-${item.key}`}
                value={item.property.title || ""}
                onChange={(e) => handlePropertyChange({ title: e.target.value || undefined })}
                placeholder="Display title"
                disabled={disabled}
                className="h-8"
                data-testid={`property-title-input-${index}`}
              />
            </div>

            <div className="flex items-end pb-1">
              <label className="flex items-center gap-2 cursor-pointer">
                <Checkbox
                  checked={item.isRequired}
                  onCheckedChange={(checked) =>
                    handleRequiredChange(checked === true)
                  }
                  disabled={disabled}
                  data-testid={`property-required-checkbox-${index}`}
                />
                <span className="text-xs">Required</span>
              </label>
            </div>
          </div>

          {/* Row 3: Description */}
          <div className="space-y-1.5">
            <Label htmlFor={`description-${item.key}`} className="text-xs">
              Description
            </Label>
            <Textarea
              id={`description-${item.key}`}
              value={item.property.description || ""}
              onChange={(e) =>
                handlePropertyChange({ description: e.target.value || undefined })
              }
              placeholder="Help text for this field"
              disabled={disabled}
              className="min-h-[60px] resize-none"
            />
          </div>

          {/* Enum values (for string/number types) */}
          {(item.property.type === "string" ||
            item.property.type === "number" ||
            item.property.type === "integer") && (
            <div className="space-y-1.5">
              <Label htmlFor={`enum-${item.key}`} className="text-xs">
                Enum Values (comma-separated, optional)
              </Label>
              <Input
                id={`enum-${item.key}`}
                value={getEnumString()}
                onChange={(e) => handleEnumChange(e.target.value)}
                placeholder="option1, option2, option3"
                disabled={disabled}
                className="h-8"
              />
            </div>
          )}

          {/* Array items type */}
          {item.property.type === "array" && (
            <div className="space-y-1.5">
              <Label htmlFor={`items-type-${item.key}`} className="text-xs">
                Array Item Type
              </Label>
              <Select
                value={item.property.items?.type || "string"}
                onValueChange={(v) =>
                  handlePropertyChange({ items: { type: v as PropertyType } })
                }
                disabled={disabled}
              >
                <SelectTrigger
                  id={`items-type-${item.key}`}
                  className="h-8 w-full"
                >
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {PROPERTY_TYPES.filter((t) => t.value !== "array").map(
                    (type) => (
                      <SelectItem key={type.value} value={type.value}>
                        {type.label}
                      </SelectItem>
                    )
                  )}
                </SelectContent>
              </Select>
            </div>
          )}

          {/* Default value */}
          <div className="space-y-1.5">
            <Label htmlFor={`default-${item.key}`} className="text-xs">
              Default Value (optional)
            </Label>
            <Input
              id={`default-${item.key}`}
              value={
                item.property.default !== undefined
                  ? String(item.property.default)
                  : ""
              }
              onChange={(e) => {
                const val = e.target.value;
                if (!val) {
                  const { default: _, ...rest } = item.property;
                  handlePropertyChange(rest);
                  return;
                }
                // Parse based on type
                let parsed: unknown = val;
                if (
                  item.property.type === "number" ||
                  item.property.type === "integer"
                ) {
                  const num = Number(val);
                  if (!isNaN(num)) parsed = num;
                } else if (item.property.type === "boolean") {
                  parsed = val === "true";
                }
                handlePropertyChange({ default: parsed });
              }}
              placeholder={
                item.property.type === "boolean" ? "true or false" : "Default value"
              }
              disabled={disabled}
              className="h-8"
            />
          </div>
        </div>
      )}
    </div>
  );
}
