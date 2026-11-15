import { and, desc, eq, gt, isNull } from "drizzle-orm";
import { db, mcpOAuthClients, mcpOAuthGrants } from "@/lib/db";
import { getSession } from "@/lib/auth-helper";
import { ensureSchemaInitialized } from "@/lib/db/client";
import { mcpResource } from "@/lib/mcp/oauth-config";
/**
 * List MCP connections
 * @operationId listMcpClients
 * @response McpClientsResponseSchema
 * @auth bearer
 * @tag MCP
 * @openapi
 */
export async function GET(request: Request) {
 const session = await getSession(request);
 if (!session) return Response.json({error:"Unauthorized"},{status:401});
 await ensureSchemaInitialized();
 const rows = await db.select({id:mcpOAuthGrants.id,name:mcpOAuthClients.name,scope:mcpOAuthGrants.scope,expiresAt:mcpOAuthGrants.expiresAt}).from(mcpOAuthGrants).innerJoin(mcpOAuthClients,eq(mcpOAuthClients.id,mcpOAuthGrants.clientId)).where(and(eq(mcpOAuthGrants.ownerId,session.user.id),isNull(mcpOAuthGrants.revokedAt),gt(mcpOAuthGrants.expiresAt,new Date()))).orderBy(desc(mcpOAuthGrants.expiresAt));
 return Response.json({url:mcpResource(),items:rows},{headers:{"Cache-Control":"no-store"}});
}
