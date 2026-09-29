import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { moveItemStockAction } from "@/lib/actions/item-stock-actions";

interface RouteParams {
  params: Promise<{ id: string }>;
}

/**
 * Move item stock
 * @operationId moveItemStock
 * @description Move some or all units of an item from one placement (its main placement or a stock placement) to another parent item. Partial moves split units into a placement under the destination parent.
 * @pathParams IdPathParams
 * @body MoveItemStockRequestSchema
 * @response 200:MoveItemStockResponseSchema
 * @auth bearer
 * @tag Items
 * @responseSet auth
 * @openapi
 */
export async function POST(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;

  try {
    const body = await request.json();
    const result = await moveItemStockAction(id, body, session.user.id);

    if (result.success && result.data) {
      return NextResponse.json(result.data);
    }
    if (result.error?.toLowerCase().includes("permission denied")) {
      return NextResponse.json({ error: result.error }, { status: 403 });
    }
    if (result.error === "Stock placement not found") {
      return NextResponse.json({ error: result.error }, { status: 404 });
    }
    return NextResponse.json({ error: result.error }, { status: 400 });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Invalid request" },
      { status: 400 },
    );
  }
}
