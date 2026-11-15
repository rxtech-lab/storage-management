import { and, eq } from "drizzle-orm";
import { db, mcpOAuthGrants } from "@/lib/db";
import { getSession } from "@/lib/auth-helper";
/**
 * Disconnect MCP client
 * @operationId disconnectMcpClient
 * @pathParams IdPathParams
 * @response 204:NoContent
 * @auth bearer
 * @tag MCP
 * @openapi
 */
export async function DELETE(request: Request, {params}: {params:Promise<{id:string}>}) {
 const session = await getSession(request);
 if (!session) return Response.json({error:"Unauthorized"},{status:401});
 const {id} = await params;
 const rows = await db.update(mcpOAuthGrants).set({revokedAt:new Date()}).where(and(eq(mcpOAuthGrants.id,id),eq(mcpOAuthGrants.ownerId,session.user.id))).returning();
 return new Response(null,{status:rows.length ? 204 : 404});
}
