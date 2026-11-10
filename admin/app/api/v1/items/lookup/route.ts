import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { POST as scanInventory } from "@/app/api/v1/qrcode/scan/route";
import { BarcodeLookupRequestSchema, BarcodeLookupResponseSchema } from "@/lib/schemas/barcode";
import { lookupBarcode, BarcodeProviderError } from "@/lib/barcode-lookup";

export const maxDuration = 30;

/**
 * Resolve inventory, ISBN books, or UPC/EAN products on the server without creating records
 * @operationId lookupItemBarcode
 * @body BarcodeLookupRequestSchema
 * @response BarcodeLookupResponseSchema
 * @auth bearer
 * @tag Items
 * @openapi
 */
export async function POST(request: NextRequest) {
  const session = await getSession(request);
  if (!session?.user?.id) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const parsed = BarcodeLookupRequestSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: "Enter a barcode up to 2000 characters" }, { status: 400 });
  const { barcode, inventory } = parsed.data;
  try {
    if (inventory) {
      const resolved = await scanInventory(new NextRequest(request.url, { method: "POST", headers: request.headers, body: JSON.stringify({ qrcontent: barcode }) }));
      if (resolved.ok) {
        const item = await resolved.json();
        return NextResponse.json(BarcodeLookupResponseSchema.parse({ barcode, itemUrl: item.url, result: null }));
      }
      // Preserve inventory permissions; never fall through on access or server errors.
      if (resolved.status !== 400) return resolved;
    }
    const result = await lookupBarcode(barcode, request.signal);
    return NextResponse.json(BarcodeLookupResponseSchema.parse({ barcode, itemUrl: null, result }));
  } catch (error) {
    return NextResponse.json({ error: error instanceof BarcodeProviderError ? error.message : "Could not look up this barcode. Please try again." }, { status: 502 });
  }
}
