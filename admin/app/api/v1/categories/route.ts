import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import {
  getCategories,
  getCategoriesPaginated,
  createCategoryAction,
  type CategoryFilters,
  type PaginatedCategoryFilters,
} from "@/lib/actions/category-actions";
import { parsePaginationParams } from "@/lib/utils/pagination";

/**
 * List categories
 * @operationId getCategories
 * @description Retrieve a paginated list of categories
 * @params CategoriesQueryParams
 * @response PaginatedCategoriesResponse
 * @auth bearer
 * @tag Categories
 * @responseSet auth
 * @openapi
 */
export async function GET(request: NextRequest) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const searchParams = request.nextUrl.searchParams;
  const filters: CategoryFilters = {};

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

    const paginatedFilters: PaginatedCategoryFilters = {
      ...filters,
      ...paginationParams,
    };

    const result = await getCategoriesPaginated(
      session.user.id,
      paginatedFilters
    );

    return NextResponse.json({
      data: result.data,
      pagination: result.pagination,
    });
  }

  // Legacy: return full array for backward compatibility
  const categories = await getCategories(
    session.user.id,
    Object.keys(filters).length > 0 ? filters : undefined
  );
  return NextResponse.json(categories);
}

/**
 * Create category
 * @operationId createCategory
 * @description Create a new category
 * @body CategoryInsertSchema
 * @response 201:CategoryResponseSchema
 * @auth bearer
 * @tag Categories
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
    const result = await createCategoryAction(body, session.user.id);

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
