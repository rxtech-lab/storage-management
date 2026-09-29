import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { unregisterDeviceAction } from "@/lib/actions/device-actions";

interface RouteParams {
  params: Promise<{ token: string }>;
}

/**
 * Unregister device
 * @operationId unregisterDevice
 * @description Stop sending push notifications to an APNs device token, e.g. when the user signs out
 * @pathParams DeviceTokenPathParams
 * @response 200:SuccessResponse
 * @auth bearer
 * @tag Devices
 * @responseSet auth
 * @openapi
 */
export async function DELETE(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { token } = await params;
  const result = await unregisterDeviceAction(token, session.user.id);

  if (result.success) {
    return NextResponse.json({ success: true });
  }
  return NextResponse.json({ error: result.error }, { status: 400 });
}
