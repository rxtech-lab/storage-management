/**
 * JSON Schema Editor Types
 *
 * Designed with extensibility for future advanced features:
 * - Nested objects
 * - min/max constraints
 * - Pattern validation
 * - Format validation
 * - Conditional schemas
 */

/** Supported basic property types */
export type PropertyType =
  | "string"
  | "number"
  | "integer"
  | "boolean"
  | "array";

/** Root schema types (includes object) */
export type RootSchemaType = PropertyType | "object";

/** Property definition for a single schema property */
export interface SchemaProperty {
  /** Property type */
  type: PropertyType;
  /** Display title for the property */
  title?: string;
  /** Description shown as help text */
  description?: string;
  /** Default value */
  default?: unknown;
  /** Enum values (for string/number types) */
  enum?: (string | number)[];
  /** Items schema (for array type) */
  items?: {
    type: PropertyType;
  };

  // Future: Advanced constraints
  // minimum?: number;
  // maximum?: number;
  // minLength?: number;
  // maxLength?: number;
  // pattern?: string;
  // format?: string;
}

/** JSON Schema structure for object type */
export interface ObjectJsonSchema {
  type: "object";
  title?: string;
  description?: string;
  properties: Record<string, SchemaProperty>;
  required?: string[];
}

/** JSON Schema structure for array type */
export interface ArrayJsonSchema {
  type: "array";
  title?: string;
  description?: string;
  items?: {
    type: PropertyType;
  };
}

/** JSON Schema structure for primitive types */
export interface PrimitiveJsonSchema {
  type: "string" | "number" | "integer" | "boolean";
  title?: string;
  description?: string;
  default?: unknown;
  enum?: (string | number | boolean)[];
}

/** Full JSON Schema structure - supports multiple root types */
export type JsonSchema = ObjectJsonSchema | ArrayJsonSchema | PrimitiveJsonSchema;

/** Internal representation of a property with its key */
export interface PropertyItem {
  /** Unique key/name for the property */
  key: string;
  /** Property definition */
  property: SchemaProperty;
  /** Whether this property is required */
  isRequired: boolean;
}

/** Props for the main JsonSchemaEditor component */
export interface JsonSchemaEditorProps {
  /** Current schema value (can be null for empty state) */
  value: JsonSchema | null;
  /** Callback when schema changes */
  onChange: (schema: JsonSchema | null) => void;
  /** Additional CSS classes */
  className?: string;
  /** Placeholder text for empty state */
  placeholder?: string;
  /** Whether the editor is disabled */
  disabled?: boolean;
}

/** Props for the PropertyEditor component */
export interface PropertyEditorProps {
  /** Property item to edit */
  item: PropertyItem;
  /** Callback when property changes */
  onChange: (item: PropertyItem) => void;
  /** Callback to delete the property */
  onDelete: () => void;
  /** Callback to move property up */
  onMoveUp?: () => void;
  /** Callback to move property down */
  onMoveDown?: () => void;
  /** Whether this is the first property (disable move up) */
  isFirst?: boolean;
  /** Whether this is the last property (disable move down) */
  isLast?: boolean;
  /** Whether the editor is disabled */
  disabled?: boolean;
}

/** Props for the PropertyList component */
export interface PropertyListProps {
  /** List of property items */
  items: PropertyItem[];
  /** Callback when items change */
  onChange: (items: PropertyItem[]) => void;
  /** Whether the editor is disabled */
  disabled?: boolean;
}

/** Available property type options for the type selector */
export const PROPERTY_TYPES: { value: PropertyType; label: string }[] = [
  { value: "string", label: "String" },
  { value: "number", label: "Number" },
  { value: "integer", label: "Integer" },
  { value: "boolean", label: "Boolean" },
  { value: "array", label: "Array" },
];

/** Available root schema type options */
export const ROOT_SCHEMA_TYPES: { value: RootSchemaType; label: string; description: string }[] = [
  { value: "object", label: "Object", description: "Schema with named properties" },
  { value: "array", label: "Array", description: "List of items" },
  { value: "string", label: "String", description: "Text value" },
  { value: "number", label: "Number", description: "Numeric value (decimal)" },
  { value: "integer", label: "Integer", description: "Numeric value (whole number)" },
  { value: "boolean", label: "Boolean", description: "True/false value" },
];

/** Default property template for new properties */
export const DEFAULT_PROPERTY: SchemaProperty = {
  type: "string",
  title: "",
};

/** Empty schema template */
export const EMPTY_SCHEMA: JsonSchema = {
  type: "object",
  properties: {},
  required: [],
};
