import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { getItem } from "@/lib/actions/item-actions";
import { getItemContentsPaginated, createContentAction, resolveContentFileRefs } from "@/lib/actions/content-actions";
import { parsePaginationParams } from "@/lib/utils/pagination";
import { PaginatedContentsResponse } from "@/lib/schemas/contents";
import type { ContentData } from "@/lib/db";

/**
 * List item contents
 * @operationId getItemContents
 * @description Returns paginated content attachments (files, images, videos) for an item with optional search
 * @pathParams IdPathParams
 * @params ContentsQueryParams
 * @response PaginatedContentsResponse
 * @auth bearer
 * @tag Contents
 * @responseSet auth
 * @openapi
 */
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;

  // Verify user owns the item
  const item = await getItem(id);
  if (!item || item.userId !== session.user.id) {
    return NextResponse.json({ error: "Item not found" }, { status: 404 });
  }

  const searchParams = request.nextUrl.searchParams;
  const paginationParams = parsePaginationParams({
    cursor: searchParams.get("cursor"),
    direction: searchParams.get("direction"),
    limit: searchParams.get("limit"),
  });

  const result = await getItemContentsPaginated(id, {
    ...paginationParams,
    search: searchParams.get("search") ?? undefined,
  });

  const signedData = await resolveContentFileRefs(result.data);
  const response = { data: signedData, pagination: result.pagination };
  const validated = PaginatedContentsResponse.safeParse(response);
  if (!validated.success) {
    console.error("Validation error:", validated.error.errors);
    return NextResponse.json({ error: "Invalid response data" }, { status: 500 });
  }
  return NextResponse.json(validated.data);
}

/**
 * Create item content
 * @operationId createItemContent
 * @description Create a new content attachment for an item
 * @pathParams IdPathParams
 * @body ContentInsertSchema
 * @response 201:ContentResponseSchema
 * @auth bearer
 * @tag Contents
 * @responseSet auth
 * @openapi
 */
export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;

  // Verify user owns the item
  const item = await getItem(id);
  if (!item || item.userId !== session.user.id) {
    return NextResponse.json({ error: "Item not found" }, { status: 404 });
  }

  const body = await request.json();
  const { type, data } = body as { type: "file" | "image" | "video"; data: ContentData };

  if (!type || !data) {
    return NextResponse.json(
      { error: "Missing required fields: type and data" },
      { status: 400 }
    );
  }

  if (!["file", "image", "video"].includes(type)) {
    return NextResponse.json(
      { error: "Invalid content type. Must be: file, image, or video" },
      { status: 400 }
    );
  }

  const result = await createContentAction({ itemId: id, type, data });

  if (!result.success) {
    return NextResponse.json({ error: result.error }, { status: 500 });
  }

  const [signed] = await resolveContentFileRefs([result.data!]);
  return NextResponse.json(signed, { status: 201 });
}
