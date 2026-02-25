import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import {
  getAccountDeletionStatus,
  requestAccountDeletion,
  cancelAccountDeletion,
} from "@/lib/actions/account-deletion-actions";

/**
 * Get account deletion status
 * @operationId getAccountDeletionStatus
 * @description Check if there is a pending account deletion request
 * @response AccountDeletionStatusResponseSchema
 * @auth bearer
 * @tag Account
 * @responseSet auth
 * @openapi
 */
export async function GET(request: NextRequest) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const status = await getAccountDeletionStatus(session.user.id);
  return NextResponse.json(status);
}

/**
 * Request account deletion
 * @operationId requestAccountDeletion
 * @description Request account deletion. Account will be deleted after 24 hours. Can be cancelled during the grace period.
 * @response 201:AccountDeletionRequestResponseSchema
 * @auth bearer
 * @tag Account
 * @responseSet auth
 * @openapi
 */
export async function POST(request: NextRequest) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  // Build the callback URL for QStash
  const protocol = request.headers.get("x-forwarded-proto") || "https";
  const host = request.headers.get("host") || "localhost:3000";
  const callbackUrl = `${protocol}://${host}/api/v1/account/delete/callback`;

  const result = await requestAccountDeletion(
    session.user.id,
    session.user.email ?? null,
    callbackUrl
  );

  if (result.success) {
    return NextResponse.json(
      {
        message:
          "Account deletion scheduled. Your account will be deleted in 24 hours. You can cancel this during the grace period.",
        deletion: result.data,
      },
      { status: 201 }
    );
  } else {
    return NextResponse.json({ error: result.error }, { status: 400 });
  }
}

/**
 * Cancel account deletion
 * @operationId cancelAccountDeletion
 * @description Cancel a pending account deletion request during the grace period
 * @response AccountDeletionCancelResponseSchema
 * @auth bearer
 * @tag Account
 * @responseSet auth
 * @openapi
 */
export async function DELETE(request: NextRequest) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const result = await cancelAccountDeletion(session.user.id);

  if (result.success) {
    return NextResponse.json({
      message: "Account deletion cancelled successfully.",
    });
  } else {
    return NextResponse.json({ error: result.error }, { status: 400 });
  }
}
