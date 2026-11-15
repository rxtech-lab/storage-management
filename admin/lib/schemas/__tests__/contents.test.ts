import { expect, it } from "vitest";
import { FileContentDataSchema, ImageContentDataSchema, VideoContentDataSchema } from "../contents";
import { contentSchemas } from "../content-schemas";

const base = { title: "file", mime_type: "application/octet-stream", size: 42, file_path: "file" };
it.each([FileContentDataSchema, ImageContentDataSchema, VideoContentDataSchema])("accepts legacy metadata and retains optional SHA-256", (schema) => {
  const metadata = { ...base, video_length: 10 };
  expect(schema.safeParse(metadata).success).toBe(true);
  const sha256 = "AB".repeat(32);
  expect(schema.parse({ ...metadata, sha256 }).sha256).toBe(sha256);
  expect(schema.safeParse({ ...metadata, sha256: "invalid" }).success).toBe(false);
});
it("exposes optional SHA-256 in each dynamic form schema", () => {
  for (const schema of Object.values(contentSchemas)) {
    expect(schema.required).not.toContain("sha256");
    expect(schema.properties?.sha256).toMatchObject({ type: "string", pattern: "^[a-fA-F0-9]{64}$" });
  }
});
