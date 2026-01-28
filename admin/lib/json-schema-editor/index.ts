// Main component
export { JsonSchemaEditor } from "./json-schema-editor";

// Sub-components (for advanced usage)
export { PropertyEditor } from "./property-editor";
export { PropertyList } from "./property-list";

// Types
export type {
  JsonSchema,
  ObjectJsonSchema,
  ArrayJsonSchema,
  PrimitiveJsonSchema,
  SchemaProperty,
  PropertyType,
  RootSchemaType,
  PropertyItem,
  JsonSchemaEditorProps,
  PropertyEditorProps,
  PropertyListProps,
} from "./types";

// Constants
export { PROPERTY_TYPES, ROOT_SCHEMA_TYPES, DEFAULT_PROPERTY, EMPTY_SCHEMA } from "./types";

// Utilities
export {
  isObjectSchema,
  schemaToPropertyItems,
  propertyItemsToSchema,
  createPropertyItem,
  generateUniqueKey,
  validatePropertyKey,
  isKeyUnique,
  validateSchema,
  parseSchemaJson,
  stringifySchema,
  moveArrayItem,
  createEmptySchema,
  createSchemaOfType,
  convertSchemaType,
} from "./schema-utils";
