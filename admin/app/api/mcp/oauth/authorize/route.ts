import { oauthResponse, authorize } from "@/lib/mcp/oauth";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(request: Request) { return oauthResponse(() => authorize(request)); }
