import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import {
  getPositionSchemas,
  getPositionSchemasPaginated,
  createPositionSchemaAction,
  type PositionSchemaFilters,
  type PaginatedPositionSchemaFilters,
} from "@/lib/actions/position-schema-actions";
import { parsePaginationParams } from "@/lib/utils/pagination";

/**
 * List position schemas
 * @operationId getPositionSchemas
 * @description Retrieve a paginated list of custom position schemas
 * @params PositionSchemasQueryParams
 * @response PaginatedPositionSchemasResponse
 * @auth bearer
 * @tag PositionSchemas
 * @responseSet auth
 * @openapi
 */
export async function GET(request: NextRequest) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const searchParams = request.nextUrl.searchParams;
  const filters: PositionSchemaFilters = {};

  if (searchParams.has("search")) {
    filters.search = searchParams.get("search")!;
  }

  // Check if pagination is requested
  const hasPaginationParams =
    searchParams.has("cursor") || searchParams.has("limit");

  if (hasPaginationParams) {
    const paginationParams = parsePaginationParams({
      cursor: searchParams.get("cursor"),
      direction: searchParams.get("direction"),
      limit: searchParams.get("limit"),
    });

    const paginatedFilters: PaginatedPositionSchemaFilters = {
      ...filters,
      ...paginationParams,
    };

    const result = await getPositionSchemasPaginated(
      session.user.id,
      paginatedFilters
    );

    return NextResponse.json({
      data: result.data,
      pagination: result.pagination,
    });
  }

  // Legacy: return full array for backward compatibility
  const schemas = await getPositionSchemas(
    session.user.id,
    Object.keys(filters).length > 0 ? filters : undefined
  );
  return NextResponse.json(schemas);
}

/**
 * Create position schema
 * @operationId createPositionSchema
 * @description Create a new custom position schema with JSON Schema definition
 * @body PositionSchemaInsertSchema
 * @response 201:PositionSchemaResponseSchema
 * @auth bearer
 * @tag PositionSchemas
 * @responseSet auth
 * @openapi
 */
export async function POST(request: NextRequest) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  try {
    const body = await request.json();
    const result = await createPositionSchemaAction(body, session.user.id);

    if (result.success) {
      return NextResponse.json(result.data, { status: 201 });
    } else {
      return NextResponse.json({ error: result.error }, { status: 400 });
    }
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Invalid request" },
      { status: 400 }
    );
  }
}
