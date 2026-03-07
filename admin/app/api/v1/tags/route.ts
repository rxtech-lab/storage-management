import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import {
  getTags,
  getTagsPaginated,
  createTagAction,
  type TagFilters,
  type PaginatedTagFilters,
} from "@/lib/actions/tag-actions";
import { parsePaginationParams } from "@/lib/utils/pagination";

/**
 * List tags
 * @operationId getTags
 * @description Retrieve a paginated list of tags
 * @params TagsQueryParams
 * @response PaginatedTagsResponse
 * @auth bearer
 * @tag Tags
 * @responseSet auth
 * @openapi
 */
export async function GET(request: NextRequest) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const searchParams = request.nextUrl.searchParams;
  const filters: TagFilters = {};

  if (searchParams.has("search")) {
    filters.search = searchParams.get("search")!;
  }

  const hasPaginationParams =
    searchParams.has("cursor") || searchParams.has("limit");

  if (hasPaginationParams) {
    const paginationParams = parsePaginationParams({
      cursor: searchParams.get("cursor"),
      direction: searchParams.get("direction"),
      limit: searchParams.get("limit"),
    });

    const paginatedFilters: PaginatedTagFilters = {
      ...filters,
      ...paginationParams,
    };

    const result = await getTagsPaginated(
      session.user.id,
      paginatedFilters
    );

    return NextResponse.json({
      data: result.data,
      pagination: result.pagination,
    });
  }

  const tags = await getTags(
    session.user.id,
    Object.keys(filters).length > 0 ? filters : undefined
  );
  return NextResponse.json(tags);
}

/**
 * Create tag
 * @operationId createTag
 * @description Create a new tag
 * @body TagInsertSchema
 * @response 201:TagResponseSchema
 * @auth bearer
 * @tag Tags
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
    const result = await createTagAction(body, session.user.id);

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
