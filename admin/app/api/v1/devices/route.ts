import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { registerDeviceAction } from "@/lib/actions/device-actions";

/**
 * Register device for push notifications
 * @operationId registerDevice
 * @description Register or refresh an APNs device token so the signed-in user receives push notifications, e.g. when an ISO job finishes
 * @body DeviceRegisterSchema
 * @response 201:DeviceResponseSchema
 * @auth bearer
 * @tag Devices
 * @responseSet auth
 * @openapi
 */
export async function POST(request: NextRequest) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  try {
    const body = await request.json();
    const result = await registerDeviceAction(body, session.user.id);

    if (result.success) {
      return NextResponse.json(result.data, { status: 201 });
    }
    return NextResponse.json({ error: result.error }, { status: 400 });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Invalid request" },
      { status: 400 }
    );
  }
}
