import { WebStandardStreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/webStandardStreamableHttp.js";
import { db } from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";
import { authenticateOAuthToken } from "@/lib/mcp/oauth-tokens";
import { authChallenge, mcpOrigin, securitySchemes } from "@/lib/mcp/oauth-config";
import { createMcpServer } from "@/lib/mcp/server";
export const runtime = "nodejs";
export async function POST(request: Request) {
  if (request.headers.has("origin") && request.headers.get("origin") !== mcpOrigin()) return new Response(null,{status:403});
  await ensureSchemaInitialized();
  const token = request.headers.get("authorization")?.match(/^Bearer (.+)$/i)?.[1];
  const principal = token ? await authenticateOAuthToken(db,token) : null;
  if (!principal) return Response.json({error:"unauthorized"},{status:401,headers:{"WWW-Authenticate":authChallenge(undefined,token ? "invalid_token" : undefined),"Cache-Control":"no-store"}});
  const server = createMcpServer(principal);
  const transport = new WebStandardStreamableHTTPServerTransport({sessionIdGenerator:undefined,enableJsonResponse:true});
  await server.connect(transport);
  try {
    const response = await transport.handleRequest(request);
    if (response.headers.get("content-type")?.includes("application/json")) {
      const rpc = await response.clone().json();
      if (Array.isArray(rpc.result?.tools)) {
        for (const tool of rpc.result.tools) tool.securitySchemes = securitySchemes(tool.name);
        return Response.json(rpc,{status:response.status,headers:response.headers});
      }
    }
    return response;
  } finally { await server.close(); }
}
function methodNotAllowed() { return new Response(null,{status:405,headers:{Allow:"POST"}}); }
export const GET = methodNotAllowed;
export const DELETE = methodNotAllowed;
