import { describe, it, expect } from "vitest";
import {
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
} from "../schema-utils";
import type { JsonSchema, PropertyItem, ObjectJsonSchema } from "../types";

describe("schemaToPropertyItems", () => {
  it("returns empty array for null schema", () => {
    expect(schemaToPropertyItems(null)).toEqual([]);
  });

  it("returns empty array for schema without properties", () => {
    const schema: JsonSchema = { type: "object", properties: {} };
    expect(schemaToPropertyItems(schema)).toEqual([]);
  });

  it("converts schema properties to property items", () => {
    const schema: JsonSchema = {
      type: "object",
      properties: {
        name: { type: "string", title: "Name" },
        age: { type: "integer", title: "Age" },
      },
      required: ["name"],
    };

    const result = schemaToPropertyItems(schema);

    expect(result).toHaveLength(2);
    expect(result[0]).toEqual({
      key: "name",
      property: { type: "string", title: "Name" },
      isRequired: true,
    });
    expect(result[1]).toEqual({
      key: "age",
      property: { type: "integer", title: "Age" },
      isRequired: false,
    });
  });
});

describe("propertyItemsToSchema", () => {
  it("converts property items to schema", () => {
    const items: PropertyItem[] = [
      { key: "name", property: { type: "string", title: "Name" }, isRequired: true },
      { key: "age", property: { type: "integer" }, isRequired: false },
    ];

    const result = propertyItemsToSchema(items);

    expect(result.type).toBe("object");
    expect(result.properties).toEqual({
      name: { type: "string", title: "Name" },
      age: { type: "integer" },
    });
    expect(result.required).toEqual(["name"]);
  });

  it("omits required array if no required fields", () => {
    const items: PropertyItem[] = [
      { key: "name", property: { type: "string" }, isRequired: false },
    ];

    const result = propertyItemsToSchema(items);

    expect(result.required).toBeUndefined();
  });

  it("filters out items with empty keys", () => {
    const items: PropertyItem[] = [
      { key: "", property: { type: "string" }, isRequired: false },
      { key: "name", property: { type: "string" }, isRequired: false },
    ];

    const result = propertyItemsToSchema(items);

    expect(Object.keys(result.properties)).toEqual(["name"]);
  });
});

describe("createPropertyItem", () => {
  it("creates property item with defaults", () => {
    const item = createPropertyItem();

    expect(item.key).toBe("");
    expect(item.property.type).toBe("string");
    expect(item.isRequired).toBe(false);
  });

  it("creates property item with custom key and type", () => {
    const item = createPropertyItem("myKey", "number");

    expect(item.key).toBe("myKey");
    expect(item.property.type).toBe("number");
  });
});

describe("generateUniqueKey", () => {
  it("returns 'property' when no existing keys", () => {
    expect(generateUniqueKey([])).toBe("property");
  });

  it("returns 'property1' when 'property' exists", () => {
    expect(generateUniqueKey(["property"])).toBe("property1");
  });

  it("returns next available number", () => {
    expect(generateUniqueKey(["property", "property1", "property2"])).toBe(
      "property3"
    );
  });
});

describe("validatePropertyKey", () => {
  it("returns invalid for empty key", () => {
    const result = validatePropertyKey("");
    expect(result.valid).toBe(false);
    expect(result.error).toBeDefined();
  });

  it("returns invalid for key starting with number", () => {
    const result = validatePropertyKey("1property");
    expect(result.valid).toBe(false);
  });

  it("returns valid for proper key", () => {
    const result = validatePropertyKey("my_property");
    expect(result.valid).toBe(true);
    expect(result.error).toBeUndefined();
  });

  it("returns valid for key starting with underscore", () => {
    const result = validatePropertyKey("_private");
    expect(result.valid).toBe(true);
  });
});

describe("isKeyUnique", () => {
  it("returns true when key is unique", () => {
    expect(isKeyUnique("newKey", ["key1", "key2"])).toBe(true);
  });

  it("returns false when key exists", () => {
    expect(isKeyUnique("key1", ["key1", "key2"])).toBe(false);
  });

  it("excludes current key from check", () => {
    expect(isKeyUnique("key1", ["key1", "key2"], "key1")).toBe(true);
  });
});

describe("validateSchema", () => {
  it("returns invalid for null", () => {
    const result = validateSchema(null);
    expect(result.valid).toBe(false);
  });

  it("returns invalid for unsupported type", () => {
    const result = validateSchema({ type: "invalid" });
    expect(result.valid).toBe(false);
  });

  it("returns valid for string type", () => {
    const result = validateSchema({ type: "string" });
    expect(result.valid).toBe(true);
  });

  it("returns valid for array type", () => {
    const result = validateSchema({ type: "array", items: { type: "string" } });
    expect(result.valid).toBe(true);
  });

  it("returns valid for proper schema", () => {
    const result = validateSchema({
      type: "object",
      properties: { name: { type: "string" } },
    });
    expect(result.valid).toBe(true);
  });

  it("returns invalid for non-object properties", () => {
    const result = validateSchema({
      type: "object",
      properties: "invalid",
    });
    expect(result.valid).toBe(false);
  });

  it("returns invalid for non-array required", () => {
    const result = validateSchema({
      type: "object",
      properties: {},
      required: "invalid",
    });
    expect(result.valid).toBe(false);
  });
});

describe("parseSchemaJson", () => {
  it("returns null schema for empty string", () => {
    const result = parseSchemaJson("");
    expect(result.schema).toBeNull();
    expect(result.error).toBeUndefined();
  });

  it("returns error for invalid JSON", () => {
    const result = parseSchemaJson("{invalid}");
    expect(result.schema).toBeNull();
    expect(result.error).toBe("Invalid JSON syntax");
  });

  it("returns error for invalid schema", () => {
    const result = parseSchemaJson('{"type": "invalid"}');
    expect(result.schema).toBeNull();
    expect(result.error).toBeDefined();
  });

  it("returns parsed schema for string type", () => {
    const result = parseSchemaJson('{"type": "string"}');
    expect(result.schema).toBeDefined();
    expect(result.schema?.type).toBe("string");
  });

  it("returns parsed schema for valid JSON", () => {
    const json = '{"type": "object", "properties": {"name": {"type": "string"}}}';
    const result = parseSchemaJson(json);
    expect(result.schema).toBeDefined();
    expect(result.error).toBeUndefined();
    expect((result.schema as ObjectJsonSchema)?.properties.name.type).toBe("string");
  });
});

describe("stringifySchema", () => {
  it("returns empty string for null", () => {
    expect(stringifySchema(null)).toBe("");
  });

  it("returns formatted JSON", () => {
    const schema: JsonSchema = {
      type: "object",
      properties: { name: { type: "string" } },
    };
    const result = stringifySchema(schema);
    expect(result).toContain('"type": "object"');
    expect(result).toContain('"properties"');
  });

  it("includes required only if present", () => {
    const schemaWithRequired: JsonSchema = {
      type: "object",
      properties: { name: { type: "string" } },
      required: ["name"],
    };
    const schemaWithoutRequired: JsonSchema = {
      type: "object",
      properties: { name: { type: "string" } },
    };

    expect(stringifySchema(schemaWithRequired)).toContain('"required"');
    expect(stringifySchema(schemaWithoutRequired)).not.toContain('"required"');
  });
});

describe("moveArrayItem", () => {
  it("moves item from one index to another", () => {
    const arr = ["a", "b", "c", "d"];
    expect(moveArrayItem(arr, 0, 2)).toEqual(["b", "c", "a", "d"]);
  });

  it("returns original array for invalid indices", () => {
    const arr = ["a", "b", "c"];
    expect(moveArrayItem(arr, -1, 2)).toEqual(arr);
    expect(moveArrayItem(arr, 0, 5)).toEqual(arr);
  });

  it("moves item up", () => {
    const arr = ["a", "b", "c"];
    expect(moveArrayItem(arr, 2, 1)).toEqual(["a", "c", "b"]);
  });
});

describe("createEmptySchema", () => {
  it("returns a new empty schema object", () => {
    const schema1 = createEmptySchema();
    const schema2 = createEmptySchema();

    expect(schema1).toEqual({
      type: "object",
      properties: {},
      required: [],
    });
    expect(schema1).not.toBe(schema2);
  });
});
