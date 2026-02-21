import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { deleteStockHistoryAction } from "@/lib/actions/stock-history-actions";

/**
 * Delete stock history entry
 * @operationId deleteStockHistory
 * @description Delete a stock history entry by ID
 * @pathParams IdPathParams
 * @response 200:SuccessResponse
 * @auth bearer
 * @tag StockHistory
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
  const stockHistoryId = parseInt(id);

  if (isNaN(stockHistoryId)) {
    return NextResponse.json({ error: "Invalid stock history ID" }, { status: 400 });
  }

  const result = await deleteStockHistoryAction(stockHistoryId, session.user.id);

  if (!result.success) {
    return NextResponse.json(
      { error: result.error || "Failed to delete stock history entry" },
      { status: 400 }
    );
  }

  return NextResponse.json({ success: true });
}
