import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { getImageUploadUrlAction } from "@/lib/actions/s3-upload-actions";

/**
 * Get presigned upload URL
 * @operationId getPresignedUploadUrl
 * @description Generate a presigned URL for direct file upload to S3. Returns upload URL, file ID, and expiration time.
 * @body PresignedUploadRequestSchema
 * @response 201:PresignedUploadResponseSchema
 * @auth bearer
 * @tag Upload
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
    const { filename, contentType, size = 0 } = body;

    if (!filename || typeof filename !== "string") {
      return NextResponse.json(
        { error: "filename is required" },
        { status: 400 }
      );
    }

    if (!contentType || typeof contentType !== "string") {
      return NextResponse.json(
        { error: "contentType is required" },
        { status: 400 }
      );
    }

    const result = await getImageUploadUrlAction(
      filename,
      contentType,
      "items",
      session.user.id,
      size
    );

    if (result.success && result.data) {
      return NextResponse.json(result.data, { status: 201 });
    } else {
      return NextResponse.json(
        { error: result.error || "Failed to generate upload URL" },
        { status: 400 }
      );
    }
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Invalid request" },
      { status: 400 }
    );
  }
}
