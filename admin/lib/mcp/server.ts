import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";
import { and, eq, isNull, like, or, desc } from "drizzle-orm";
import { db, items, contents } from "@/lib/db";
import { updateItemAction, deleteItemAction } from "@/lib/actions/item-actions";
import { getImageUploadUrlAction, signImagesArrayWithIds } from "@/lib/actions/s3-upload-actions";
import { resolveContentFileRefs } from "@/lib/actions/content-actions";
import { toolScope, securitySchemes } from "./oauth-config";
import type { McpPrincipal } from "./oauth-tokens";

export async function ownedItem(id: string, userId: string) {
  const [item] = await db.select().from(items).where(and(eq(items.id, id), eq(items.userId, userId), isNull(items.deletedAt))).limit(1);
  if (!item) throw new Error("Item not found");
  return item;
}

export async function validateParent(id: string, parentId: string | null, userId: string) {
  await ownedItem(id, userId);
  const visited = new Set([id]);
  let next = parentId;
  while (next) {
    if (visited.has(next)) throw new Error("An item cannot be its own ancestor");
    visited.add(next);
    next = (await ownedItem(next, userId)).parentId;
  }
}

export function createMcpServer(principal: McpPrincipal) {
  const server = new McpServer({ name: "RxStorage", version: "1.0.0" });
  function tool<T extends z.ZodRawShape>(name: string, description: string, schema: T, run: (args: z.infer<z.ZodObject<T>>) => Promise<unknown>) {
    // Erase only the SDK generic overload; the local helper retains schema inference.
    const register = server.registerTool.bind(server) as unknown as (name: string, config: {description: string; inputSchema: z.ZodRawShape; annotations: Record<string, boolean>; _meta: Record<string, unknown>}, callback: (args: unknown) => Promise<CallToolResult>) => void;
    register(name, { description, inputSchema: schema, annotations: { readOnlyHint: toolScope(name) === "storage:read", destructiveHint: name === "delete_item", openWorldHint: false }, _meta: { securitySchemes: securitySchemes(name) } }, async args => {
      if (!principal.scopes.includes(toolScope(name))) return { isError: true, content: [{ type: "text", text: "Permission required. Reconnect with the required scope." }], _meta: { "mcp/www_authenticate": [`Bearer error="insufficient_scope", scope="${toolScope(name)}"`] } };
      try { return { content: [{ type: "text", text: JSON.stringify(await run(args as z.infer<z.ZodObject<T>>)) }] }; }
      catch (error) { return { isError: true, content: [{ type: "text", text: error instanceof Error ? error.message : "Operation failed" }] }; }
    });
  }
  tool("find_items", "Find your active items by title or description. Paginated; excludes recycle bin.", { query: z.string().max(500).default(""), limit: z.number().int().min(1).max(100).default(25), offset: z.number().int().min(0).default(0) }, async ({query, limit, offset}) => {
    const rows = await db.select().from(items).where(and(eq(items.userId, principal.sub), isNull(items.deletedAt), or(like(items.title, `%${query}%`), like(items.description, `%${query}%`)))).orderBy(desc(items.createdAt), desc(items.id)).limit(limit + 1).offset(offset);
    return { items: await Promise.all(rows.slice(0,limit).map(async item => ({...item, images: await signImagesArrayWithIds(item.images ?? [])}))), nextOffset: rows.length > limit ? offset + limit : null };
  });
  tool("read_item", "Read one of your active inventory items.", { id: z.string().min(1) }, async ({id}) => {
    const item = await ownedItem(id, principal.sub);
    return {...item, images: await signImagesArrayWithIds(item.images ?? [])};
  });
  tool("update_item", "Update an item. Upload images first, then pass file:{fileId} references. Use set_parent to move items.", { id: z.string().min(1), title: z.string().min(1).optional(), description: z.string().nullable().optional(), price: z.number().nonnegative().nullable().optional(), currency: z.string().length(3).optional(), images: z.array(z.string().regex(/^file:[\w-]+$/)).max(50).optional() }, async ({id, ...patch}) => {
    await ownedItem(id, principal.sub);
    const result = await updateItemAction(id, patch, principal.sub);
    if (!result.success) throw new Error(result.error);
    return result.data;
  });
  tool("delete_item", "Move an item to the recycle bin. Only the iOS app can permanently delete it.", { id: z.string().min(1) }, async ({id}) => {
    await ownedItem(id, principal.sub);
    const result = await deleteItemAction(id, principal.sub);
    if (!result.success) throw new Error(result.error);
    return { deleted: true, recoverable: true };
  });
  tool("list_contents", "List attachments belonging to an item, with signed file URLs.", { id: z.string().min(1), limit: z.number().int().min(1).max(100).default(25), offset: z.number().int().min(0).default(0) }, async ({id,limit,offset}) => {
    await ownedItem(id, principal.sub);
    const rows = await db.select().from(contents).where(eq(contents.itemId,id)).orderBy(desc(contents.id)).limit(limit+1).offset(offset);
    return { items: await resolveContentFileRefs(rows.slice(0,limit)), nextOffset: rows.length > limit ? offset+limit : null };
  });
  tool("set_parent", "Move an item to another owned item, or set parentId to null to move to the root. Prevents cycles.", { id: z.string().min(1), parentId: z.string().min(1).nullable() }, async ({id,parentId}) => {
    await validateParent(id,parentId,principal.sub);
    const result = await updateItemAction(id,{parentId},principal.sub);
    if (!result.success) throw new Error(result.error);
    return result.data;
  });
  tool("get_image_upload_url", "Get a presigned S3 PUT URL. Upload bytes directly to uploadUrl with Content-Type, then use file:{fileId} in update_item.images. Never send image bytes to this server.", { filename: z.string().min(1).max(255), contentType: z.enum(["image/jpeg","image/png","image/webp","image/heic","image/gif"]), size: z.number().int().positive().max(100*1024*1024) }, async ({filename,contentType,size}) => {
    const result = await getImageUploadUrlAction(filename,contentType,"items",principal.sub,size);
    if (!result.success) throw new Error(result.error);
    return {...result.data, method: "PUT", headers: {"Content-Type":contentType}};
  });
  return server;
}
