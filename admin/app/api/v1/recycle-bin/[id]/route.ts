import { getSession } from "@/lib/auth-helper";
import { purgeItem, restoreItem } from "@/lib/mcp/recycle-bin";
/**
 * Permanently delete recycled item
 * @operationId purgeRecycledItem
 * @pathParams IdPathParams
 * @response 204:NoContent
 * @auth bearer
 * @tag RecycleBin
 * @openapi
 */
export async function DELETE(request:Request,{params}:{params:Promise<{id:string}>}) {
 return mutate(request,(await params).id,false);
}
/**
 * Restore recycled item
 * @operationId restoreRecycledItem
 * @pathParams IdPathParams
 * @response 204:NoContent
 * @auth bearer
 * @tag RecycleBin
 * @openapi
 */
export async function POST(request:Request,{params}:{params:Promise<{id:string}>}) {
 return mutate(request,(await params).id,true);
}
async function mutate(request:Request,id:string,restore:boolean) {
 const session = await getSession(request);
 if (!session) return Response.json({error:"Unauthorized"},{status:401});
 try { await (restore ? restoreItem : purgeItem)(id,session.user.id); return new Response(null,{status:204}); }
 catch { return Response.json({error:"Item not found or operation failed"},{status:400}); }
}
