import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { getItem } from "@/lib/actions/item-actions";
import QRCode from "qrcode";

interface RouteParams {
  params: Promise<{ id: string }>;
}

export async function GET(request: NextRequest, { params }: RouteParams) {
  const session = await getSession();
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const item = await getItem(parseInt(id));

  if (!item) {
    return NextResponse.json({ error: "Item not found" }, { status: 404 });
  }

  // Get the base URL from the request or environment
  const baseUrl = request.headers.get("origin") || process.env.NEXT_PUBLIC_BASE_URL || "http://localhost:3000";
  const previewUrl = `${baseUrl}/preview/${id}`;

  try {
    // Generate QR code as data URL
    const qrDataUrl = await QRCode.toDataURL(previewUrl, {
      width: 400,
      margin: 2,
      color: {
        dark: "#000000",
        light: "#ffffff",
      },
    });

    return NextResponse.json({
      data: {
        item_id: parseInt(id),
        item_title: item.title,
        preview_url: previewUrl,
        qr_code_data_url: qrDataUrl,
      },
    });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Failed to generate QR code" },
      { status: 500 }
    );
  }
}
