import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { getItemPositions } from "@/lib/actions/position-actions";
import { getItem } from "@/lib/actions/item-actions";

/**
 * List item positions
 * @operationId getItemPositions
 * @description Returns all position data entries for an item
 * @pathParams IdPathParams
 * @response PositionsListResponse
 * @auth bearer
 * @tag Positions
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

  const positions = await getItemPositions(itemId);
  return NextResponse.json(positions);
}
