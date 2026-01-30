import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { getImageUploadUrlAction } from "@/lib/actions/s3-upload-actions";

/**
 * POST /api/v1/upload/presigned
 *
 * Request body:
 * - filename: string (required) - Original filename
 * - contentType: string (required) - MIME type (must start with "image/")
 * - size: number (optional) - File size in bytes
 *
 * Response:
 * - uploadUrl: string - Presigned URL for uploading to S3
 * - fileId: number - Database file record ID
 * - key: string - S3 object key
 * - expiresAt: string - ISO timestamp when the upload URL expires
 *
 * Note: File record is created immediately. File existence in S3 will be
 * verified when the file is associated with an item via POST/PUT /api/v1/items.
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
