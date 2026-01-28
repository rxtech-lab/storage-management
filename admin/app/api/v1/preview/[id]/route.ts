import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { getItem } from "@/lib/actions/item-actions";
import { getItemContents } from "@/lib/actions/content-actions";
import { getLocation } from "@/lib/actions/location-actions";
import { isEmailWhitelisted } from "@/lib/actions/whitelist-actions";

interface RouteParams {
  params: Promise<{ id: string }>;
}

export async function GET(request: NextRequest, { params }: RouteParams) {
  const { id } = await params;
  const itemId = parseInt(id);

  const item = await getItem(itemId);

  if (!item) {
    return NextResponse.json({ error: "Item not found" }, { status: 404 });
  }

  // Check visibility
  if (item.visibility === "private") {
    const session = await getSession(request);

    if (!session?.user?.email) {
      return NextResponse.json(
        { error: "Authentication required", visibility: "private" },
        { status: 401 }
      );
    }

    // Skip whitelist check in e2e mode (auth is already bypassed)
    if (process.env.IS_E2E !== "true") {
      const hasAccess = await isEmailWhitelisted(itemId, session.user.email);

      if (!hasAccess) {
        return NextResponse.json(
          { error: "Access denied", visibility: "private" },
          { status: 403 }
        );
      }
    }
  }

  // Fetch additional data
  const [contents, location] = await Promise.all([
    getItemContents(itemId),
    item.locationId ? getLocation(item.locationId) : null,
  ]);

  return NextResponse.json({
    data: {
      ...item,
      location: location || item.location,
      contents,
    },
  });
}
