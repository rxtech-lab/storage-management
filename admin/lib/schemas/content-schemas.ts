import type { JSONSchema7 } from "json-schema";

export const fileSchema: JSONSchema7 = {
  type: "object",
  required: ["title", "mime_type", "size", "file_path"],
  properties: {
    title: { type: "string", title: "Title", description: "Display name for the file" },
    description: { type: "string", title: "Description", description: "Optional description or notes about the file" },
    mime_type: { type: "string", title: "MIME Type", description: "File type (e.g., application/pdf, text/plain)" },
    size: { type: "number", title: "Size (bytes)", description: "File size in bytes" },
    file_path: { type: "string", title: "File Path", description: "Storage path or URL to the file" },
  },
};

export const imageSchema: JSONSchema7 = {
  type: "object",
  required: ["title", "mime_type", "size", "file_path"],
  properties: {
    title: { type: "string", title: "Title", description: "Display name for the image" },
    description: { type: "string", title: "Description", description: "Optional description or notes about the image" },
    mime_type: { type: "string", title: "MIME Type", description: "Image type (e.g., image/jpeg, image/png)" },
    size: { type: "number", title: "Size (bytes)", description: "File size in bytes" },
    file_path: { type: "string", title: "File Path", description: "Storage path or URL to the image" },
    preview_image_url: { type: "string", title: "Preview Image URL", description: "URL for thumbnail or preview version" },
  },
};

export const videoSchema: JSONSchema7 = {
  type: "object",
  required: ["title", "mime_type", "size", "file_path", "video_length"],
  properties: {
    title: { type: "string", title: "Title", description: "Display name for the video" },
    description: { type: "string", title: "Description", description: "Optional description or notes about the video" },
    mime_type: { type: "string", title: "MIME Type", description: "Video type (e.g., video/mp4, video/webm)" },
    size: { type: "number", title: "Size (bytes)", description: "File size in bytes" },
    file_path: { type: "string", title: "File Path", description: "Storage path or URL to the video" },
    preview_image_url: { type: "string", title: "Preview Image URL", description: "URL for video thumbnail" },
    video_length: { type: "number", title: "Video Length (seconds)", description: "Duration of the video in seconds" },
    preview_video_url: { type: "string", title: "Preview Video URL", description: "URL for preview/trailer version" },
  },
};

export type ContentType = "file" | "image" | "video";

export const contentSchemas: Record<ContentType, JSONSchema7> = {
  file: fileSchema,
  image: imageSchema,
  video: videoSchema,
};
