import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { getItem, findItemByOriginalQrCode } from "@/lib/actions/item-actions";
import { isEmailWhitelisted } from "@/lib/actions/whitelist-actions";
import {
  QrCodeScanRequestSchema,
  QrCodeScanResponseSchema,
} from "@/lib/schemas/qrcode";
import type { Item } from "@/lib/db";

interface PermissionResult {
  error?: string;
  status?: number;
}

interface Session {
  user: {
    id: string;
    email?: string | null;
  };
}

/**
 * Check if the user has permission to access the item
 */
async function checkItemPermission(
  item: Item,
  session: Session | null,
): Promise<PermissionResult> {
  // Public items are accessible to anyone
  if (item.visibility === "publicAccess") {
    return {};
  }

  // Private items require auth
  if (!session) {
    return { error: "Unauthorized", status: 401 };
  }

  // Owner always has access
  if (item.userId === session.user.id) {
    return {};
  }

  // Check whitelist
  if (session.user.email) {
    const whitelisted = await isEmailWhitelisted(item.id, session.user.email);
    if (whitelisted) {
      return {};
    }
  }

  return { error: "Permission denied", status: 403 };
}

/**
 * Scan QR code and resolve to item URL
 * @operationId scanQrCode
 * @description Scan a QR code content and resolve it to an item API URL. Supports preview URL format (preview/item/:id) and raw QR codes stored in items.
 * @body QrCodeScanRequestSchema
 * @response QrCodeScanResponseSchema
 * @auth bearer
 * @tag QRCode
 * @responseSet auth
 * @openapi
 */
export async function POST(request: NextRequest) {
  // Get session (optional - public items don't require auth)
  const session = await getSession(request);

  // Parse and validate body
  let body;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { error: "Invalid request body" },
      { status: 400 },
    );
  }

  const parsed = QrCodeScanRequestSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { error: "Invalid request body" },
      { status: 400 },
    );
  }

  const { qrcontent } = parsed.data;
  const baseUrl = process.env.NEXT_PUBLIC_URL || "http://localhost:3000";

  // Pattern A: Match preview/item/:id format (with or without full URL)
  // Matches:
  // - preview/item/123
  // - /preview/item/123
  // - https://storage.rxlab.app/preview/item/123
  // - http://localhost:3000/preview/item/123
  const previewMatch = qrcontent.match(/(?:^|\/)?preview\/item\/(\d+)(?:$|[?#])/);
  if (previewMatch) {
    const itemId = parseInt(previewMatch[1]);
    const item = await getItem(itemId);

    if (!item) {
      return NextResponse.json({ error: "Invalid QR code" }, { status: 400 });
    }

    const permissionResult = await checkItemPermission(item, session);
    if (permissionResult.error) {
      return NextResponse.json(
        { error: permissionResult.error },
        { status: permissionResult.status },
      );
    }

    const response = QrCodeScanResponseSchema.parse({
      type: "item",
      url: `${baseUrl}/api/v1/items/${itemId}`,
    });

    return NextResponse.json(response);
  }

  // Pattern B: Raw QR code lookup in originalQrCode field
  const item = await findItemByOriginalQrCode(qrcontent);
  if (item) {
    const permissionResult = await checkItemPermission(item, session);
    if (permissionResult.error) {
      return NextResponse.json(
        { error: permissionResult.error },
        { status: permissionResult.status },
      );
    }

    const response = QrCodeScanResponseSchema.parse({
      type: "item",
      url: `${baseUrl}/api/v1/items/${item.id}`,
    });

    return NextResponse.json(response);
  }

  // No match found
  return NextResponse.json({ error: "Invalid QR code" }, { status: 400 });
}
