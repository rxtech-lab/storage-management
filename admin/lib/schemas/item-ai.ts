import { z } from "zod";

export const ItemAIRequestSchema = z.object({
  prompt: z.string().trim().max(8000).default(""),
  title: z.string().max(500).default(""),
  description: z.string().max(8000).default(""),
  originalQrCode: z.string().max(2000).default(""),
  images: z.array(z.string().regex(/^file:[\w-]+$/)).max(5).default([]),
  webSearch: z.boolean().default(true),
}).refine(v => !!(v.prompt || v.title || v.originalQrCode || v.images.length), {
  message: "Describe the item, enter a QR code, or attach an image",
});
export const ItemAIDraftSchema = z.object({
  title: z.string().min(1).max(500),
  description: z.string().max(8000),
  originalQrCode: z.string().max(2000).nullable(),
  category: z.string().max(100).nullable(),
  author: z.string().max(100).nullable(),
  tags: z.array(z.string().min(1).max(100)).max(8),
});
export const ItemAIResponseSchema = z.object({
  draft: ItemAIDraftSchema,
  sources: z.array(z.object({ title: z.string(), url: z.string().url() })),
});
export type ItemAIDraft = z.infer<typeof ItemAIDraftSchema>;
export type ItemAIResponse = z.infer<typeof ItemAIResponseSchema>;

export const ItemAIRelationsRequestSchema = z.object({
  category: z.string().trim().min(1).max(100).nullable(),
  author: z.string().trim().min(1).max(100).nullable(),
  tags: z.array(z.string().trim().min(1).max(100)).max(8),
});
export const ItemAIRelationsResponseSchema = z.object({
  categoryId: z.string().nullable(),
  authorId: z.string().nullable(),
  tagIds: z.array(z.string()),
});
