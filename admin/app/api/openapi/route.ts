import { NextRequest, NextResponse } from "next/server";
import fs from "fs";
import path from "path";

/**
 * Get OpenAPI specification
 * @description Returns the OpenAPI 3.0 specification for the Storage Management API
 * @response object
 * @tag Documentation
 * @openapi
 */
export async function GET(request: NextRequest) {
  const openapiPath = path.join(process.cwd(), "public", "openapi.json");

  try {
    const spec = JSON.parse(fs.readFileSync(openapiPath, "utf-8"));

    // Dynamically generate servers URL from request host
    const host = request.headers.get("host") || "localhost:3000";
    const protocol = request.headers.get("x-forwarded-proto") || "http";
    const baseUrl = `${protocol}://${host}`;

    spec.servers = [
      {
        url: baseUrl,
        description: "Current server",
      },
    ];

    return new NextResponse(JSON.stringify(spec, null, 2), {
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  } catch {
    return NextResponse.json(
      {
        error:
          "OpenAPI specification not found. Run 'bun openapi:generate' first.",
      },
      { status: 404 },
    );
  }
}
