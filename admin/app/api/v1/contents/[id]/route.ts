import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { getItem } from "@/lib/actions/item-actions";
import {
  getContent,
  updateContentAction,
  deleteContentAction,
} from "@/lib/actions/content-actions";
import type { ContentData } from "@/lib/db";

/**
 * Get content by ID
 * @operationId getContent
 * @description Retrieve a single content attachment by its ID
 * @pathParams IdPathParams
 * @response ContentResponseSchema
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
  const contentId = parseInt(id);

  if (isNaN(contentId)) {
    return NextResponse.json({ error: "Invalid content ID" }, { status: 400 });
  }

  const content = await getContent(contentId);
  if (!content) {
    return NextResponse.json({ error: "Content not found" }, { status: 404 });
  }

  // Verify user owns the associated item
  const item = await getItem(content.itemId);
  if (!item || item.userId !== session.user.id) {
    return NextResponse.json({ error: "Content not found" }, { status: 404 });
  }

  return NextResponse.json(content);
}

/**
 * Update content
 * @operationId updateContent
 * @description Update an existing content attachment
 * @pathParams IdPathParams
 * @body ContentUpdateSchema
 * @response ContentResponseSchema
 * @auth bearer
 * @tag Contents
 * @responseSet auth
 * @openapi
 */
export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const contentId = parseInt(id);

  if (isNaN(contentId)) {
    return NextResponse.json({ error: "Invalid content ID" }, { status: 400 });
  }

  // Verify content exists and user owns it
  const content = await getContent(contentId);
  if (!content) {
    return NextResponse.json({ error: "Content not found" }, { status: 404 });
  }

  const item = await getItem(content.itemId);
  if (!item || item.userId !== session.user.id) {
    return NextResponse.json({ error: "Content not found" }, { status: 404 });
  }

  const body = await request.json();
  const { type, data } = body as { type?: "file" | "image" | "video"; data?: ContentData };

  if (type && !["file", "image", "video"].includes(type)) {
    return NextResponse.json(
      { error: "Invalid content type. Must be: file, image, or video" },
      { status: 400 }
    );
  }

  const result = await updateContentAction(contentId, { type, data });

  if (!result.success) {
    return NextResponse.json({ error: result.error }, { status: 500 });
  }

  return NextResponse.json(result.data);
}

/**
 * Delete content
 * @operationId deleteContent
 * @description Delete a content attachment by ID
 * @pathParams IdPathParams
 * @response 200:SuccessResponse
 * @auth bearer
 * @tag Contents
 * @responseSet auth
 * @openapi
 */
export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const contentId = parseInt(id);

  if (isNaN(contentId)) {
    return NextResponse.json({ error: "Invalid content ID" }, { status: 400 });
  }

  // Verify content exists and user owns it
  const content = await getContent(contentId);
  if (!content) {
    return NextResponse.json({ error: "Content not found" }, { status: 404 });
  }

  const item = await getItem(content.itemId);
  if (!item || item.userId !== session.user.id) {
    return NextResponse.json({ error: "Content not found" }, { status: 404 });
  }

  const result = await deleteContentAction(contentId);

  if (!result.success) {
    return NextResponse.json({ error: result.error }, { status: 500 });
  }

  return NextResponse.json({ success: true });
}
