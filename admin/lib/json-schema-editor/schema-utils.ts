import type {
  JsonSchema,
  ObjectJsonSchema,
  PropertyItem,
  SchemaProperty,
  PropertyType,
  RootSchemaType,
} from "./types";
import { DEFAULT_PROPERTY, EMPTY_SCHEMA } from "./types";

/**
 * Check if a schema is an object schema
 */
export function isObjectSchema(schema: JsonSchema | null): schema is ObjectJsonSchema {
  return schema !== null && schema.type === "object";
}

/**
 * Convert a JSON Schema to an array of PropertyItems for editing
 */
export function schemaToPropertyItems(schema: JsonSchema | null): PropertyItem[] {
  if (!schema || !isObjectSchema(schema) || !schema.properties) {
    return [];
  }

  const required = new Set(schema.required || []);

  return Object.entries(schema.properties).map(([key, property]) => ({
    key,
    property: property as SchemaProperty,
    isRequired: required.has(key),
  }));
}

/**
 * Convert an array of PropertyItems back to an Object JSON Schema
 */
export function propertyItemsToSchema(items: PropertyItem[]): ObjectJsonSchema {
  const properties: Record<string, SchemaProperty> = {};
  const required: string[] = [];

  for (const item of items) {
    if (item.key.trim()) {
      properties[item.key] = item.property;
      if (item.isRequired) {
        required.push(item.key);
      }
    }
  }

  return {
    type: "object",
    properties,
    required: required.length > 0 ? required : undefined,
  };
}

/**
 * Create a new property item with default values
 */
export function createPropertyItem(
  key: string = "",
  type: PropertyType = "string",
): PropertyItem {
  return {
    key,
    property: { ...DEFAULT_PROPERTY, type },
    isRequired: false,
  };
}

/**
 * Generate a unique property key that doesn't conflict with existing keys
 */
export function generateUniqueKey(existingKeys: string[]): string {
  const keySet = new Set(existingKeys);
  let counter = 1;
  let key = "property";

  while (keySet.has(key)) {
    key = `property${counter}`;
    counter++;
  }

  return key;
}

/**
 * Validate a property key
 * - Must not be empty
 * - Must be a valid identifier (letters, numbers, underscores, starts with letter or underscore)
 */
export function validatePropertyKey(key: string): { valid: boolean; error?: string } {
  if (!key.trim()) {
    return { valid: false, error: "Property name is required" };
  }

  // JSON Schema property names can contain any characters, but we'll be more restrictive
  // for better compatibility and readability
  const validKeyRegex = /^[a-zA-Z_][a-zA-Z0-9_]*$/;
  if (!validKeyRegex.test(key)) {
    return {
      valid: false,
      error: "Property name must start with a letter or underscore and contain only letters, numbers, and underscores",
    };
  }

  return { valid: true };
}

/**
 * Check if a key is unique among existing keys
 */
export function isKeyUnique(key: string, existingKeys: string[], currentKey?: string): boolean {
  const otherKeys = currentKey
    ? existingKeys.filter((k) => k !== currentKey)
    : existingKeys;
  return !otherKeys.includes(key);
}

/** Valid root schema types */
const VALID_SCHEMA_TYPES = ["object", "array", "string", "number", "integer", "boolean"];

/**
 * Validate a JSON Schema object
 */
export function validateSchema(schema: unknown): { valid: boolean; error?: string } {
  if (!schema || typeof schema !== "object") {
    return { valid: false, error: "Schema must be an object" };
  }

  const s = schema as Record<string, unknown>;

  if (!s.type || !VALID_SCHEMA_TYPES.includes(s.type as string)) {
    return { valid: false, error: `Schema type must be one of: ${VALID_SCHEMA_TYPES.join(", ")}` };
  }

  // Object-specific validation
  if (s.type === "object") {
    if (s.properties && typeof s.properties !== "object") {
      return { valid: false, error: "Schema properties must be an object" };
    }
    if (s.required && !Array.isArray(s.required)) {
      return { valid: false, error: "Schema required must be an array" };
    }
  }

  // Array-specific validation
  if (s.type === "array") {
    if (s.items && typeof s.items !== "object") {
      return { valid: false, error: "Schema items must be an object" };
    }
  }

  return { valid: true };
}

/**
 * Parse a JSON string into a schema, with error handling
 */
export function parseSchemaJson(jsonString: string): {
  schema: JsonSchema | null;
  error?: string;
} {
  if (!jsonString.trim()) {
    return { schema: null };
  }

  try {
    const parsed = JSON.parse(jsonString);
    const validation = validateSchema(parsed);

    if (!validation.valid) {
      return { schema: null, error: validation.error };
    }

    return { schema: parsed as JsonSchema };
  } catch {
    return { schema: null, error: "Invalid JSON syntax" };
  }
}

/**
 * Stringify a schema to formatted JSON
 */
export function stringifySchema(schema: JsonSchema | null): string {
  if (!schema) {
    return "";
  }

  // Build a clean schema object, omitting undefined values
  const cleanSchema: Record<string, unknown> = {
    type: schema.type,
  };

  if (schema.title) cleanSchema.title = schema.title;
  if (schema.description) cleanSchema.description = schema.description;

  if (isObjectSchema(schema)) {
    cleanSchema.properties = schema.properties || {};
    if (schema.required && schema.required.length > 0) {
      cleanSchema.required = schema.required;
    }
  } else if (schema.type === "array") {
    if (schema.items) cleanSchema.items = schema.items;
  } else {
    // Primitive types
    if ("default" in schema && schema.default !== undefined) {
      cleanSchema.default = schema.default;
    }
    if ("enum" in schema && schema.enum) {
      cleanSchema.enum = schema.enum;
    }
  }

  return JSON.stringify(cleanSchema, null, 2);
}

/**
 * Move an item in an array from one index to another
 */
export function moveArrayItem<T>(array: T[], fromIndex: number, toIndex: number): T[] {
  if (
    fromIndex < 0 ||
    fromIndex >= array.length ||
    toIndex < 0 ||
    toIndex >= array.length
  ) {
    return array;
  }

  const newArray = [...array];
  const [item] = newArray.splice(fromIndex, 1);
  newArray.splice(toIndex, 0, item);
  return newArray;
}

/**
 * Create a copy of the empty object schema
 */
export function createEmptySchema(): ObjectJsonSchema {
  return { type: "object", properties: {}, required: [] };
}

/**
 * Create a schema of a specific type
 */
export function createSchemaOfType(type: RootSchemaType): JsonSchema {
  switch (type) {
    case "object":
      return { type: "object", properties: {} };
    case "array":
      return { type: "array", items: { type: "string" } };
    case "string":
      return { type: "string" };
    case "number":
      return { type: "number" };
    case "integer":
      return { type: "integer" };
    case "boolean":
      return { type: "boolean" };
    default:
      return { type: "object", properties: {} };
  }
}

/**
 * Convert a schema to a different type, preserving common fields
 */
export function convertSchemaType(schema: JsonSchema | null, newType: RootSchemaType): JsonSchema {
  const base = createSchemaOfType(newType);

  // Preserve title and description if they exist
  if (schema?.title) {
    (base as { title?: string }).title = schema.title;
  }
  if (schema?.description) {
    (base as { description?: string }).description = schema.description;
  }

  return base;
}
