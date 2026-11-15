import { oauthResponse, consentPage, approveConsent } from "@/lib/mcp/oauth";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(request: Request) { return oauthResponse(() => consentPage(request)); }
export async function POST(request: Request) { return oauthResponse(() => approveConsent(request)); }
