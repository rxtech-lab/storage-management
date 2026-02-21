import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { getItem } from "@/lib/actions/item-actions";
import {
  getItemStockHistory,
  createStockHistoryAction,
} from "@/lib/actions/stock-history-actions";

/**
 * List item stock history
 * @operationId getItemStockHistory
 * @description Returns all stock history entries for an item, ordered by most recent first
 * @pathParams IdPathParams
 * @response StockHistoriesListResponse
 * @auth bearer
 * @tag StockHistory
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

  const history = await getItemStockHistory(itemId);
  return NextResponse.json(history);
}

/**
 * Create stock history entry
 * @operationId createItemStockHistory
 * @description Create a new stock history entry for an item
 * @pathParams IdPathParams
 * @body StockHistoryInsertSchema
 * @response 201:StockHistoryResponseSchema
 * @auth bearer
 * @tag StockHistory
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
  const { quantity, note } = body as { quantity: number; note?: string };

  if (quantity === undefined || typeof quantity !== "number" || !Number.isInteger(quantity)) {
    return NextResponse.json(
      { error: "Missing or invalid required field: quantity (must be integer)" },
      { status: 400 }
    );
  }

  const result = await createStockHistoryAction(
    { itemId, quantity, note: note ?? null },
    session.user.id
  );

  if (!result.success) {
    return NextResponse.json({ error: result.error }, { status: 500 });
  }

  return NextResponse.json(result.data, { status: 201 });
}
