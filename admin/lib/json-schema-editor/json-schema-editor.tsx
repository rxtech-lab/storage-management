"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Textarea } from "@/components/ui/textarea";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { cn } from "@/lib/utils";
import type {
  JsonSchemaEditorProps,
  JsonSchema,
  PropertyItem,
  RootSchemaType,
  PropertyType,
} from "./types";
import { ROOT_SCHEMA_TYPES, PROPERTY_TYPES } from "./types";
import { PropertyList } from "./property-list";
import {
  schemaToPropertyItems,
  propertyItemsToSchema,
  parseSchemaJson,
  stringifySchema,
  createEmptySchema,
  isObjectSchema,
  createSchemaOfType,
  convertSchemaType,
} from "./schema-utils";

export function JsonSchemaEditor({
  value,
  onChange,
  className,
  placeholder = "Define your schema properties...",
  disabled = false,
}: JsonSchemaEditorProps) {
  // Track when we're syncing from external value changes to prevent infinite loops
  const isSyncingFromValue = useRef(false);

  // Current schema type
  const [schemaType, setSchemaType] = useState<RootSchemaType>(
    () => value?.type || "object"
  );

  // Internal state for property items (visual editor - for object type)
  const [items, setItems] = useState<PropertyItem[]>(() =>
    schemaToPropertyItems(value)
  );

  // Internal state for raw JSON (raw editor)
  const [rawJson, setRawJson] = useState<string>(() => stringifySchema(value));

  // Track which tab was last active to sync data
  const [activeTab, setActiveTab] = useState<"visual" | "raw">("visual");

  // Error state for raw JSON
  const [jsonError, setJsonError] = useState<string | undefined>();

  // Non-object schema fields
  const [title, setTitle] = useState<string>(() => value?.title || "");
  const [description, setDescription] = useState<string>(
    () => value?.description || ""
  );
  const [arrayItemsType, setArrayItemsType] = useState<PropertyType>(
    () =>
      (value?.type === "array" && value.items?.type) || "string"
  );
  const [enumValues, setEnumValues] = useState<string>(() => {
    if (value && "enum" in value && value.enum) {
      return value.enum.join(", ");
    }
    return "";
  });
  const [defaultValue, setDefaultValue] = useState<string>(() => {
    if (value && "default" in value && value.default !== undefined) {
      return String(value.default);
    }
    return "";
  });

  // Sync state when value changes externally
  useEffect(() => {
    // Mark that we're syncing from external value to prevent infinite loops
    isSyncingFromValue.current = true;

    setSchemaType(value?.type || "object");
    setItems(schemaToPropertyItems(value));
    setRawJson(stringifySchema(value));
    setJsonError(undefined);
    setTitle(value?.title || "");
    setDescription(value?.description || "");

    if (value?.type === "array" && value.items) {
      setArrayItemsType(value.items.type || "string");
    }
    if (value && "enum" in value && value.enum) {
      setEnumValues(value.enum.join(", "));
    } else {
      setEnumValues("");
    }
    if (value && "default" in value && value.default !== undefined) {
      setDefaultValue(String(value.default));
    } else {
      setDefaultValue("");
    }

    // Reset the flag after all state updates have been processed
    // Using requestAnimationFrame to ensure it runs after React's batched updates
    const rafId = requestAnimationFrame(() => {
      isSyncingFromValue.current = false;
    });

    return () => cancelAnimationFrame(rafId);
  }, [value]);

  // Build schema from current state
  const buildSchema = useCallback((): JsonSchema | null => {
    if (schemaType === "object") {
      const schema = propertyItemsToSchema(items);
      if (title) schema.title = title;
      if (description) schema.description = description;
      return schema;
    }

    if (schemaType === "array") {
      const schema: JsonSchema = {
        type: "array",
        items: { type: arrayItemsType },
      };
      if (title) (schema as { title?: string }).title = title;
      if (description) (schema as { description?: string }).description = description;
      return schema;
    }

    // Primitive types
    const schema: JsonSchema = { type: schemaType } as JsonSchema;
    if (title) (schema as { title?: string }).title = title;
    if (description) (schema as { description?: string }).description = description;

    if (enumValues.trim()) {
      const values = enumValues.split(",").map((v) => v.trim()).filter(Boolean);
      if (values.length > 0) {
        if (schemaType === "number" || schemaType === "integer") {
          (schema as { enum?: number[] }).enum = values.map(Number).filter((n) => !isNaN(n));
        } else if (schemaType === "boolean") {
          (schema as { enum?: boolean[] }).enum = values.map((v) => v.toLowerCase() === "true");
        } else {
          (schema as { enum?: string[] }).enum = values;
        }
      }
    }

    if (defaultValue.trim()) {
      let parsedDefault: unknown = defaultValue;
      if (schemaType === "number" || schemaType === "integer") {
        const num = Number(defaultValue);
        if (!isNaN(num)) parsedDefault = num;
      } else if (schemaType === "boolean") {
        parsedDefault = defaultValue.toLowerCase() === "true";
      }
      (schema as { default?: unknown }).default = parsedDefault;
    }

    return schema;
  }, [schemaType, items, title, description, arrayItemsType, enumValues, defaultValue]);

  // Handle type change
  const handleTypeChange = useCallback(
    (newType: RootSchemaType) => {
      setSchemaType(newType);
      const newSchema = convertSchemaType(value, newType);
      setRawJson(stringifySchema(newSchema));
      setItems(schemaToPropertyItems(newSchema));
      onChange(newSchema);
    },
    [value, onChange]
  );

  // Handle visual editor changes for object type
  const handleItemsChange = useCallback(
    (newItems: PropertyItem[]) => {
      setItems(newItems);
      const schema = propertyItemsToSchema(newItems);
      if (title) schema.title = title;
      if (description) schema.description = description;
      setRawJson(stringifySchema(schema));
      setJsonError(undefined);
      onChange(Object.keys(schema.properties).length > 0 ? schema : createEmptySchema());
    },
    [onChange, title, description]
  );

  // Handle non-object field changes
  const handleFieldChange = useCallback(() => {
    const schema = buildSchema();
    if (schema) {
      setRawJson(stringifySchema(schema));
      setJsonError(undefined);
      onChange(schema);
    }
  }, [buildSchema, onChange]);

  // Trigger field change when relevant state changes
  useEffect(() => {
    // Skip if we're syncing from external value changes to prevent infinite loops
    if (isSyncingFromValue.current) {
      return;
    }
    if (schemaType !== "object" && activeTab === "visual") {
      handleFieldChange();
    }
  }, [schemaType, title, description, arrayItemsType, enumValues, defaultValue, activeTab, handleFieldChange]);

  // Handle raw JSON changes
  const handleRawJsonChange = useCallback(
    (newJson: string) => {
      setRawJson(newJson);

      if (!newJson.trim()) {
        setJsonError(undefined);
        setItems([]);
        onChange(null);
        return;
      }

      const { schema, error } = parseSchemaJson(newJson);

      if (error) {
        setJsonError(error);
        return;
      }

      setJsonError(undefined);

      if (schema) {
        setSchemaType(schema.type);
        setItems(schemaToPropertyItems(schema));
        setTitle(schema.title || "");
        setDescription(schema.description || "");

        if (schema.type === "array" && schema.items) {
          setArrayItemsType(schema.items.type || "string");
        }
        if ("enum" in schema && schema.enum) {
          setEnumValues(schema.enum.join(", "));
        }
        if ("default" in schema && schema.default !== undefined) {
          setDefaultValue(String(schema.default));
        }

        onChange(schema);
      }
    },
    [onChange]
  );

  // Sync data when switching tabs
  const handleTabChange = (newTab: string) => {
    const tab = newTab as "visual" | "raw";

    if (activeTab === "visual" && tab === "raw") {
      // Switching to raw: update JSON from current state
      const schema = buildSchema();
      if (schema) {
        setRawJson(stringifySchema(schema));
      }
    } else if (activeTab === "raw" && tab === "visual") {
      // Switching to visual: update state from JSON (if valid)
      if (!jsonError && rawJson.trim()) {
        const { schema } = parseSchemaJson(rawJson);
        if (schema) {
          setSchemaType(schema.type);
          setItems(schemaToPropertyItems(schema));
          setTitle(schema.title || "");
          setDescription(schema.description || "");
        }
      }
    }

    setActiveTab(tab);
  };

  const renderVisualEditor = () => {
    return (
      <div className="space-y-4">
        {/* Type Selector */}
        <div className="flex items-center gap-4">
          <div className="space-y-1.5">
            <Label className="text-xs">Schema Type</Label>
            <Select
              value={schemaType}
              onValueChange={(v) => handleTypeChange(v as RootSchemaType)}
              disabled={disabled}
            >
              <SelectTrigger className="w-[180px]" data-testid="json-schema-type-select">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {ROOT_SCHEMA_TYPES.map((type) => (
                  <SelectItem key={type.value} value={type.value}>
                    {type.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </div>

        {/* Common fields: title and description */}
        <div className="grid grid-cols-2 gap-4">
          <div className="space-y-1.5">
            <Label className="text-xs">Title (optional)</Label>
            <Input
              value={title}
              onChange={(e) => {
                setTitle(e.target.value);
                if (schemaType === "object") {
                  const schema = propertyItemsToSchema(items);
                  if (e.target.value) schema.title = e.target.value;
                  if (description) schema.description = description;
                  setRawJson(stringifySchema(schema));
                  onChange(schema);
                }
              }}
              placeholder="Schema title"
              disabled={disabled}
              className="h-8"
            />
          </div>
          <div className="space-y-1.5">
            <Label className="text-xs">Description (optional)</Label>
            <Input
              value={description}
              onChange={(e) => {
                setDescription(e.target.value);
                if (schemaType === "object") {
                  const schema = propertyItemsToSchema(items);
                  if (title) schema.title = title;
                  if (e.target.value) schema.description = e.target.value;
                  setRawJson(stringifySchema(schema));
                  onChange(schema);
                }
              }}
              placeholder="Schema description"
              disabled={disabled}
              className="h-8"
            />
          </div>
        </div>

        {/* Type-specific content */}
        {schemaType === "object" && (
          <PropertyList
            items={items}
            onChange={handleItemsChange}
            disabled={disabled}
          />
        )}

        {schemaType === "array" && (
          <div className="space-y-1.5">
            <Label className="text-xs">Array Item Type</Label>
            <Select
              value={arrayItemsType}
              onValueChange={(v) => setArrayItemsType(v as PropertyType)}
              disabled={disabled}
            >
              <SelectTrigger className="w-[180px]">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {PROPERTY_TYPES.filter((t) => t.value !== "array").map((type) => (
                  <SelectItem key={type.value} value={type.value}>
                    {type.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        )}

        {(schemaType === "string" ||
          schemaType === "number" ||
          schemaType === "integer" ||
          schemaType === "boolean") && (
          <div className="space-y-4">
            <div className="space-y-1.5">
              <Label className="text-xs">
                Enum Values (comma-separated, optional)
              </Label>
              <Input
                value={enumValues}
                onChange={(e) => setEnumValues(e.target.value)}
                placeholder={
                  schemaType === "boolean"
                    ? "true, false"
                    : "option1, option2, option3"
                }
                disabled={disabled}
                className="h-8"
              />
            </div>
            <div className="space-y-1.5">
              <Label className="text-xs">Default Value (optional)</Label>
              <Input
                value={defaultValue}
                onChange={(e) => setDefaultValue(e.target.value)}
                placeholder={
                  schemaType === "boolean" ? "true or false" : "Default value"
                }
                disabled={disabled}
                className="h-8"
              />
            </div>
          </div>
        )}
      </div>
    );
  };

  return (
    <div className={cn("space-y-2", className)}>
      <Tabs value={activeTab} onValueChange={handleTabChange}>
        <TabsList>
          <TabsTrigger value="visual" disabled={disabled} data-testid="json-schema-tab-visual">
            Visual Editor
          </TabsTrigger>
          <TabsTrigger value="raw" disabled={disabled} data-testid="json-schema-tab-raw">
            Raw JSON
          </TabsTrigger>
        </TabsList>

        <TabsContent value="visual" className="mt-4">
          {renderVisualEditor()}
        </TabsContent>

        <TabsContent value="raw" className="mt-4">
          <div className="space-y-2">
            <Textarea
              value={rawJson}
              onChange={(e) => handleRawJsonChange(e.target.value)}
              placeholder={`{\n  "type": "object",\n  "properties": {\n    "example": {\n      "type": "string",\n      "title": "Example Field"\n    }\n  }\n}`}
              disabled={disabled}
              className={cn(
                "font-mono text-sm min-h-[300px] resize-y",
                jsonError && "border-destructive focus-visible:ring-destructive"
              )}
              data-testid="json-schema-raw-textarea"
            />
            {jsonError && (
              <p className="text-sm text-destructive" data-testid="json-schema-error">{jsonError}</p>
            )}
            {!rawJson.trim() && !jsonError && (
              <p className="text-sm text-muted-foreground">{placeholder}</p>
            )}
          </div>
        </TabsContent>
      </Tabs>
    </div>
  );
}
