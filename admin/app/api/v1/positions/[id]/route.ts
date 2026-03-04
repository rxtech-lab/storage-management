import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import {
  getPosition,
  deletePositionAction,
} from "@/lib/actions/position-actions";

/**
 * Get position by ID
 * @description Retrieve a single position by its ID
 * @pathParams IdPathParams
 * @response PositionResponseSchema
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

  const position = await getPosition(id);
  if (!position || position.userId !== session.user.id) {
    return NextResponse.json({ error: "Position not found" }, { status: 404 });
  }

  return NextResponse.json(position);
}

/**
 * Delete position
 * @operationId deletePosition
 * @description Delete a position by ID
 * @pathParams IdPathParams
 * @response 200:SuccessResponse
 * @auth bearer
 * @tag Positions
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

  const result = await deletePositionAction(id, session.user.id);

  if (!result.success) {
    return NextResponse.json(
      { error: result.error || "Failed to delete position" },
      { status: 400 }
    );
  }

  return NextResponse.json({ success: true });
}
