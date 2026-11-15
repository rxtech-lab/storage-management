import { and, desc, eq, isNotNull } from "drizzle-orm";
import { db, items } from "@/lib/db";
import { getSession } from "@/lib/auth-helper";
import { ensureSchemaInitialized } from "@/lib/db/client";
import { purgeItem } from "@/lib/mcp/recycle-bin";
/**
 * List recycle bin
 * @operationId listRecycleBin
 * @response RecycleBinResponseSchema
 * @auth bearer
 * @tag RecycleBin
 * @openapi
 */
export async function GET(request:Request) {
 const session = await getSession(request);
 if (!session) return Response.json({error:"Unauthorized"},{status:401});
 await ensureSchemaInitialized();
 return Response.json({items:await db.select({id:items.id,title:items.title,deletedAt:items.deletedAt}).from(items).where(and(eq(items.userId,session.user.id),isNotNull(items.deletedAt))).orderBy(desc(items.deletedAt))},{headers:{"Cache-Control":"no-store"}});
}
/**
 * Empty recycle bin
 * @operationId emptyRecycleBin
 * @response 204:NoContent
 * @auth bearer
 * @tag RecycleBin
 * @openapi
 */
export async function DELETE(request:Request) {
 const session = await getSession(request);
 if (!session) return Response.json({error:"Unauthorized"},{status:401});
 const rows = await db.select({id:items.id}).from(items).where(and(eq(items.userId,session.user.id),isNotNull(items.deletedAt)));
 try { for (const row of rows) await purgeItem(row.id,session.user.id); }
 catch { return Response.json({error:"Some items could not be deleted. Refresh and retry."},{status:500}); }
 return new Response(null,{status:204});
}
