import { resourceMetadata } from "@/lib/mcp/oauth-config";
export function GET() { return Response.json(resourceMetadata()); }
