import { z } from "zod";
export const McpClientsResponseSchema = z.object({url:z.string(),items:z.array(z.object({id:z.string(),name:z.string(),scope:z.string(),expiresAt:z.coerce.date()}))});
export const RecycleBinResponseSchema = z.object({items:z.array(z.object({id:z.string(),title:z.string(),deletedAt:z.coerce.date().nullable()}))});
