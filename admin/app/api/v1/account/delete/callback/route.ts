import { NextRequest, NextResponse } from "next/server";
import { executeAccountDeletion } from "@/lib/actions/account-deletion-actions";

/**
 * QStash callback to execute account deletion
 * @description This endpoint is called by QStash after the 24-hour grace period.
 * It is not part of the public API and should only be called by QStash.
 */
export async function POST(request: NextRequest) {
  // Verify QStash signature in production
  if (process.env.IS_E2E !== "true") {
    try {
      const { Receiver } = await import("@upstash/qstash");
      const receiver = new Receiver({
        currentSigningKey: process.env.QSTASH_CURRENT_SIGNING_KEY!,
        nextSigningKey: process.env.QSTASH_NEXT_SIGNING_KEY!,
      });

      const body = await request.text();
      const signature = request.headers.get("upstash-signature");

      if (!signature) {
        return NextResponse.json(
          { error: "Missing signature" },
          { status: 401 }
        );
      }

      const isValid = await receiver.verify({
        signature,
        body,
        url: request.url,
      });

      if (!isValid) {
        return NextResponse.json(
          { error: "Invalid signature" },
          { status: 401 }
        );
      }

      const { userId } = JSON.parse(body);

      if (!userId) {
        return NextResponse.json(
          { error: "Missing userId" },
          { status: 400 }
        );
      }

      const result = await executeAccountDeletion(userId);

      if (result.success) {
        return NextResponse.json({ message: "Account deleted successfully" });
      } else {
        return NextResponse.json({ error: result.error }, { status: 400 });
      }
    } catch (error) {
      console.error("QStash callback error:", error);
      return NextResponse.json(
        { error: "Internal server error" },
        { status: 500 }
      );
    }
  }

  // E2E mode - no signature verification
  try {
    const { userId } = await request.json();

    if (!userId) {
      return NextResponse.json(
        { error: "Missing userId" },
        { status: 400 }
      );
    }

    const result = await executeAccountDeletion(userId);

    if (result.success) {
      return NextResponse.json({ message: "Account deleted successfully" });
    } else {
      return NextResponse.json({ error: result.error }, { status: 400 });
    }
  } catch (error) {
    console.error("Callback error:", error);
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    );
  }
}
