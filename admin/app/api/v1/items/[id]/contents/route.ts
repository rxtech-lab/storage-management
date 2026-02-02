import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { getItem } from "@/lib/actions/item-actions";
import { getItemContents, createContentAction } from "@/lib/actions/content-actions";
import type { ContentData } from "@/lib/db";

/**
 * List item contents
 * @operationId getItemContents
 * @description Returns all content attachments (files, images, videos) for an item
 * @pathParams IdPathParams
 * @response ContentsListResponse
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
  const itemId = parseInt(id);

  if (isNaN(itemId)) {
    return NextResponse.json({ error: "Invalid item ID" }, { status: 400 });
  }

  // Verify user owns the item
  const item = await getItem(itemId);
  if (!item || item.userId !== session.user.id) {
    return NextResponse.json({ error: "Item not found" }, { status: 404 });
  }

  const contents = await getItemContents(itemId);
  return NextResponse.json(contents);
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
  const itemId = parseInt(id);

  if (isNaN(itemId)) {
    return NextResponse.json({ error: "Invalid item ID" }, { status: 400 });
  }

  // Verify user owns the item
  const item = await getItem(itemId);
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

  const result = await createContentAction({ itemId, type, data });

  if (!result.success) {
    return NextResponse.json({ error: result.error }, { status: 500 });
  }

  return NextResponse.json(result.data, { status: 201 });
}
