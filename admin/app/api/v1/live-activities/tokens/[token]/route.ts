import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { unregisterLiveActivityTokenAction } from "@/lib/actions/live-activity-actions";

interface RouteParams {
  params: Promise<{ token: string }>;
}

/**
 * Unregister Live Activity push token
 * @operationId unregisterLiveActivityToken
 * @description Stop sending Live Activity pushes to an ActivityKit push token, e.g. when the user signs out
 * @pathParams LiveActivityTokenPathParams
 * @response 200:SuccessResponse
 * @auth bearer
 * @tag LiveActivities
 * @responseSet auth
 * @openapi
 */
export async function DELETE(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { token } = await params;
  const result = await unregisterLiveActivityTokenAction(token, session.user.id);

  if (result.success) {
    return NextResponse.json({ success: true });
  }
  return NextResponse.json({ error: result.error }, { status: 400 });
}
