import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { getItem } from "@/lib/actions/item-actions";
import {
  getItemContents,
  getItemContentsPaginated,
  createContentAction,
  deleteContentAction,
  resolveContentFileRefs,
} from "@/lib/actions/content-actions";
import { parsePaginationParams } from "@/lib/utils/pagination";
import { SHA256Schema, PaginatedContentsResponse } from "@/lib/schemas/contents";
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
 * @description Create a new content attachment for an item. A matching SHA-256 within the item returns 400, including with overwrite. With overwrite, existing content with the same title is replaced.
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
  const { type, data, overwrite } = body as {
    type: "file" | "image" | "video";
    data: ContentData;
    overwrite?: boolean;
  };

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

  if (data.sha256 !== undefined && !SHA256Schema.safeParse(data.sha256).success) {
    return NextResponse.json(
      { error: "SHA-256 must be 64 hexadecimal characters" },
      { status: 400 }
    );
  }

  const existing = data.sha256 || overwrite ? await getItemContents(id) : [];
  if (data.sha256 && existing.some((content) =>
    content.data.sha256?.toLowerCase() === data.sha256!.toLowerCase()
  )) {
    return NextResponse.json(
      { error: "Content with the same SHA-256 already exists for this item" },
      { status: 400 }
    );
  }

  if (overwrite && typeof data.title === "string") {
    for (const content of existing) {
      if ((content.data as unknown as Record<string, unknown>)?.title !== data.title) continue;
      const deleted = await deleteContentAction(content.id);
      if (!deleted.success) {
        return NextResponse.json(
          { error: deleted.error || "Failed to replace existing content" },
          { status: 500 }
        );
      }
    }
  }

  const result = await createContentAction({ itemId: id, type, data });

  if (!result.success) {
    return NextResponse.json({ error: result.error }, { status: 500 });
  }

  const [signed] = await resolveContentFileRefs([result.data!]);
  return NextResponse.json(signed, { status: 201 });
}
