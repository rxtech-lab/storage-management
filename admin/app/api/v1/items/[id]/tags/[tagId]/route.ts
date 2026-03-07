import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { getItem } from "@/lib/actions/item-actions";
import { removeItemTag } from "@/lib/actions/tag-actions";

interface RouteParams {
  params: Promise<{ id: string; tagId: string }>;
}

/**
 * Remove tag from item
 * @operationId removeItemTag
 * @description Remove a tag from an item
 * @pathParams ItemTagPathParams
 * @response 200:SuccessResponse
 * @auth bearer
 * @tag Tags
 * @responseSet auth
 * @openapi
 */
export async function DELETE(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id, tagId } = await params;

  const item = await getItem(id);
  if (!item || item.userId !== session.user.id) {
    return NextResponse.json({ error: "Item not found" }, { status: 404 });
  }

  const result = await removeItemTag(id, tagId);

  if (result.success) {
    return NextResponse.json({ success: true });
  } else {
    return NextResponse.json({ error: result.error }, { status: 400 });
  }
}
