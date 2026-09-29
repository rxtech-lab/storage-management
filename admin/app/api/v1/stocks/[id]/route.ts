import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import {
  updateItemStockAction,
  deleteItemStockAction,
} from "@/lib/actions/item-stock-actions";

interface RouteParams {
  params: Promise<{ id: string }>;
}

function errorStatus(error?: string): number {
  if (error === "Permission denied") return 403;
  if (error === "Stock placement not found") return 404;
  return 400;
}

/**
 * Update stock placement
 * @operationId updateItemStock
 * @description Update the location, images, note, and positions of a stock placement. Positions, when provided, replace the existing ones.
 * @pathParams IdPathParams
 * @body ItemStockUpdateSchema
 * @response ItemStockResponseSchema
 * @auth bearer
 * @tag StockHistory
 * @responseSet auth
 * @openapi
 */
export async function PUT(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;

  try {
    const body = await request.json();
    const result = await updateItemStockAction(id, body, session.user.id);
    if (!result.success || !result.data) {
      return NextResponse.json({ error: result.error }, { status: errorStatus(result.error) });
    }
    return NextResponse.json(result.data);
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Invalid request" },
      { status: 400 },
    );
  }
}

/**
 * Delete stock placement
 * @operationId deleteItemStock
 * @description Remove a stock placement and return its units to the item's main placement
 * @pathParams IdPathParams
 * @response 200:SuccessResponse
 * @auth bearer
 * @tag StockHistory
 * @responseSet auth
 * @openapi
 */
export async function DELETE(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const result = await deleteItemStockAction(id, session.user.id);
  if (!result.success) {
    return NextResponse.json({ error: result.error }, { status: errorStatus(result.error) });
  }
  return NextResponse.json({ success: true });
}
