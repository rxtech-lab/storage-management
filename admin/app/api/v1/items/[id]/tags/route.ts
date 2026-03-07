import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { getItem } from "@/lib/actions/item-actions";
import { getItemTags, addItemTag } from "@/lib/actions/tag-actions";
import { getTag } from "@/lib/actions/tag-actions";
import { ItemTagResponseSchema, TagRefSchema } from "@/lib/schemas/tags";
import { z } from "zod";

interface RouteParams {
  params: Promise<{ id: string }>;
}

/**
 * List item tags
 * @operationId getItemTags
 * @description Get all tags associated with an item
 * @pathParams IdPathParams
 * @response ItemTagsListResponse
 * @auth bearer
 * @tag Tags
 * @responseSet auth
 * @openapi
 */
export async function GET(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;

  const item = await getItem(id);
  if (!item || item.userId !== session.user.id) {
    return NextResponse.json({ error: "Item not found" }, { status: 404 });
  }

  const tags = await getItemTags(id);
  return NextResponse.json(tags);
}

/**
 * Add tag to item
 * @operationId addItemTag
 * @description Add a tag to an item
 * @pathParams IdPathParams
 * @body ItemTagInsertSchema
 * @response 201:ItemTagResponseSchema
 * @auth bearer
 * @tag Tags
 * @responseSet auth
 * @openapi
 */
export async function POST(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;

  const item = await getItem(id);
  if (!item || item.userId !== session.user.id) {
    return NextResponse.json({ error: "Item not found" }, { status: 404 });
  }

  try {
    const body = await request.json();
    const { tagId } = body as { tagId: string };

    if (!tagId) {
      return NextResponse.json(
        { error: "Missing required field: tagId" },
        { status: 400 }
      );
    }

    // Verify tag exists and belongs to user
    const tag = await getTag(tagId);
    if (!tag || tag.userId !== session.user.id) {
      return NextResponse.json({ error: "Tag not found" }, { status: 404 });
    }

    const result = await addItemTag(id, tagId);

    if (!result.success) {
      return NextResponse.json({ error: result.error }, { status: 400 });
    }

    return NextResponse.json(
      {
        id: `${id}_${tag.id}`,
        itemId: id,
        tagId: tag.id,
        tag: { id: tag.id, title: tag.title, color: tag.color },
        createdAt: new Date().toISOString(),
      },
      { status: 201 }
    );
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Invalid request" },
      { status: 400 }
    );
  }
}
