import type { JSONSchema7 } from "json-schema";

export const fileSchema: JSONSchema7 = {
  type: "object",
  required: ["title", "mime_type", "size", "file_path"],
  properties: {
    title: { type: "string", title: "Title" },
    description: { type: "string", title: "Description" },
    mime_type: { type: "string", title: "MIME Type" },
    size: { type: "number", title: "Size (bytes)" },
    file_path: { type: "string", title: "File Path" },
  },
};

export const imageSchema: JSONSchema7 = {
  type: "object",
  required: ["title", "mime_type", "size", "file_path"],
  properties: {
    title: { type: "string", title: "Title" },
    description: { type: "string", title: "Description" },
    mime_type: { type: "string", title: "MIME Type" },
    size: { type: "number", title: "Size (bytes)" },
    file_path: { type: "string", title: "File Path" },
    preview_image_url: { type: "string", title: "Preview Image URL" },
  },
};

export const videoSchema: JSONSchema7 = {
  type: "object",
  required: ["title", "mime_type", "size", "file_path", "video_length"],
  properties: {
    title: { type: "string", title: "Title" },
    description: { type: "string", title: "Description" },
    mime_type: { type: "string", title: "MIME Type" },
    size: { type: "number", title: "Size (bytes)" },
    file_path: { type: "string", title: "File Path" },
    preview_image_url: { type: "string", title: "Preview Image URL" },
    video_length: { type: "number", title: "Video Length (seconds)" },
    preview_video_url: { type: "string", title: "Preview Video URL" },
  },
};

export type ContentType = "file" | "image" | "video";

export const contentSchemas: Record<ContentType, JSONSchema7> = {
  file: fileSchema,
  image: imageSchema,
  video: videoSchema,
};
