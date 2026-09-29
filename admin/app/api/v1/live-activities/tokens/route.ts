import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { registerLiveActivityTokenAction } from "@/lib/actions/live-activity-actions";

/**
 * Register Live Activity push token
 * @operationId registerLiveActivityToken
 * @description Register an ActivityKit push token. A start token lets the server start the ISO jobs Live Activity when a job starts; an update token lets it update and end that activity as the user's jobs progress
 * @body LiveActivityTokenRegisterSchema
 * @response 201:LiveActivityTokenResponseSchema
 * @auth bearer
 * @tag LiveActivities
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
    const result = await registerLiveActivityTokenAction(body, session.user.id);

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
