import { oauthResponse, revoke } from "@/lib/mcp/oauth";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: Request) { return oauthResponse(() => revoke(request)); }
