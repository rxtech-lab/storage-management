import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { getItem } from "@/lib/actions/item-actions";
import {
  getItemWhitelist,
  addToWhitelistAction,
  removeFromWhitelistAction,
} from "@/lib/actions/whitelist-actions";

interface RouteParams {
  params: Promise<{ id: string }>;
}

/**
 * List whitelist entries
 * @operationId getItemWhitelist
 * @description Returns all whitelisted emails for a private item (owner only)
 * @pathParams IdPathParams
 * @response WhitelistListResponse
 * @auth bearer
 * @tag Whitelists
 * @responseSet auth
 * @openapi
 */
export async function GET(request: NextRequest, { params }: RouteParams) {
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
  if (!item) {
    return NextResponse.json({ error: "Item not found" }, { status: 404 });
  }

  if (item.userId !== session.user.id) {
    return NextResponse.json({ error: "Permission denied" }, { status: 403 });
  }

  const whitelist = await getItemWhitelist(itemId);
  return NextResponse.json(whitelist);
}

/**
 * Add to whitelist
 * @operationId addToWhitelist
 * @description Add an email address to the whitelist for accessing a private item
 * @pathParams IdPathParams
 * @body WhitelistAddRequestSchema
 * @response 201:WhitelistResponseSchema
 * @auth bearer
 * @tag Whitelists
 * @responseSet auth
 * @openapi
 */
export async function POST(request: NextRequest, { params }: RouteParams) {
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
  if (!item) {
    return NextResponse.json({ error: "Item not found" }, { status: 404 });
  }

  if (item.userId !== session.user.id) {
    return NextResponse.json({ error: "Permission denied" }, { status: 403 });
  }

  const body = await request.json();
  const { email } = body as { email: string };

  if (!email) {
    return NextResponse.json(
      { error: "Missing required field: email" },
      { status: 400 }
    );
  }

  const result = await addToWhitelistAction({ itemId, email });

  if (!result.success) {
    return NextResponse.json({ error: result.error }, { status: 500 });
  }

  return NextResponse.json(result.data, { status: 201 });
}

/**
 * Remove from whitelist
 * @operationId removeFromWhitelist
 * @description Remove an email from the whitelist
 * @pathParams IdPathParams
 * @body WhitelistRemoveRequestSchema
 * @response 200:SuccessResponse
 * @auth bearer
 * @tag Whitelists
 * @responseSet auth
 * @openapi
 */
export async function DELETE(request: NextRequest, { params }: RouteParams) {
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
  if (!item) {
    return NextResponse.json({ error: "Item not found" }, { status: 404 });
  }

  if (item.userId !== session.user.id) {
    return NextResponse.json({ error: "Permission denied" }, { status: 403 });
  }

  const body = await request.json();
  const { whitelistId } = body as { whitelistId: number };

  if (!whitelistId) {
    return NextResponse.json(
      { error: "Missing required field: whitelistId" },
      { status: 400 }
    );
  }

  const result = await removeFromWhitelistAction(whitelistId);

  if (!result.success) {
    return NextResponse.json({ error: result.error }, { status: 500 });
  }

  return NextResponse.json({ success: true });
}
