import { NextRequest, NextResponse } from "next/server";
import { PutObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { getSession } from "@/lib/auth-helper";
import { createFileRecordAction } from "@/lib/actions/file-actions";
import { createContentAction, getItemContents } from "@/lib/actions/content-actions";
import { s3Client, S3_BUCKET } from "@/lib/s3";
import { ContentPreviewUploadRequestSchema } from "@/lib/schemas/upload";
import type { ImageContentData, VideoContentData } from "@/lib/db/schema/contents";

function generatePreviewKey(filename: string, suffix: string): string {
  const timestamp = Date.now();
  const randomId = crypto.randomUUID().slice(0, 8);
  const sanitizedFilename = filename.replace(/[^a-zA-Z0-9.-]/g, "_");
  return `previews/${timestamp}-${randomId}-${suffix}-${sanitizedFilename}`;
}

async function generatePresignedPutUrl(key: string, contentType: string): Promise<string> {
  const command = new PutObjectCommand({
    Bucket: S3_BUCKET,
    Key: key,
    ContentType: contentType,
  });
  return getSignedUrl(s3Client, command, { expiresIn: 600 });
}

/**
 * Generate presigned upload URLs for content previews
 * @operationId getContentPreviewUploadUrls
 * @description Generate presigned PUT URLs for uploading content preview files. For video type, returns both image thumbnail and video preview URLs. For image type, returns only image preview URL.
 * @body ContentPreviewUploadRequestSchema
 * @response ContentPreviewUploadResponseSchema
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
    const parsed = ContentPreviewUploadRequestSchema.safeParse(body);

    if (!parsed.success) {
      return NextResponse.json(
        { error: parsed.error.issues.map((i) => i.message).join(", ") },
        { status: 400 }
      );
    }

    const { item_id: itemId, items } = parsed.data;

    if (items.length === 0) {
      return NextResponse.json([], { status: 201 });
    }

    // Validate video items have video_length
    for (const item of items) {
      if (item.type === "video" && (item.video_length == null || item.video_length < 0)) {
        return NextResponse.json(
          { error: "video_length is required for video type" },
          { status: 400 }
        );
      }
    }

    // Check for duplicate filenames within the batch
    const filenames = items.map((item) => item.filename);
    const uniqueFilenames = new Set(filenames);
    if (uniqueFilenames.size !== filenames.length) {
      const duplicates = filenames.filter((name, index) => filenames.indexOf(name) !== index);
      return NextResponse.json(
        { error: `Duplicate filenames in upload: ${[...new Set(duplicates)].join(", ")}` },
        { status: 400 }
      );
    }

    // Check for duplicate filenames against existing content for the item
    const existingContents = await getItemContents(itemId);
    const existingTitles = new Set(
      existingContents.map((c) => (c.data as unknown as { title: string }).title)
    );
    const duplicateWithExisting = items.filter((item) => existingTitles.has(item.title));
    if (duplicateWithExisting.length > 0) {
      return NextResponse.json(
        { error: `Content with the same name already exists: ${duplicateWithExisting.map((i) => i.title).join(", ")}` },
        { status: 400 }
      );
    }

    const isE2E = process.env.IS_E2E === "true";
    const results = [];

    for (const item of items) {
      const imageKey = generatePreviewKey(item.filename, "thumb");

      if (isE2E) {
        // E2E mock mode
        const mockImageKey = `mock/previews/${Date.now()}-thumb-${item.filename.replace(/[^a-zA-Z0-9.-]/g, "_")}`;
        const imageFileRecord = await createFileRecordAction(
          { key: mockImageKey, filename: `thumb-${item.filename}`, contentType: "image/jpeg", size: 0 },
          session.user.id
        );

        if (!imageFileRecord.success || !imageFileRecord.data) {
          return NextResponse.json(
            { error: imageFileRecord.error || "Failed to create file record" },
            { status: 500 }
          );
        }

        const result: { id: string; imageUrl: string; videoUrl?: string } = {
          id: imageFileRecord.data.id,
          imageUrl: `https://mock-s3.example.com/upload/${mockImageKey}`,
        };

        let contentData: ImageContentData | VideoContentData;

        if (item.type === "video") {
          const mockVideoKey = `mock/previews/${Date.now()}-video-${item.filename.replace(/[^a-zA-Z0-9.-]/g, "_")}`;
          const videoFileRecord = await createFileRecordAction(
            { key: mockVideoKey, filename: `preview-${item.filename}`, contentType: item.mime_type, size: 0 },
            session.user.id
          );

          if (!videoFileRecord.success || !videoFileRecord.data) {
            return NextResponse.json(
              { error: videoFileRecord.error || "Failed to create file record" },
              { status: 500 }
            );
          }

          result.videoUrl = `https://mock-s3.example.com/upload/${mockVideoKey}`;

          contentData = {
            title: item.title,
            description: item.description,
            mime_type: item.mime_type,
            size: item.size,
            file_path: item.file_path,
            preview_image_url: `file:${imageFileRecord.data.id}`,
            preview_video_url: `file:${videoFileRecord.data.id}`,
            video_length: item.video_length!,
          } as VideoContentData;
        } else {
          contentData = {
            title: item.title,
            description: item.description,
            mime_type: item.mime_type,
            size: item.size,
            file_path: item.file_path,
            preview_image_url: `file:${imageFileRecord.data.id}`,
          } as ImageContentData;
        }

        const contentResult = await createContentAction({
          itemId,
          type: item.type === "video" ? "video" : "image",
          data: contentData,
        });

        if (!contentResult.success) {
          return NextResponse.json(
            { error: contentResult.error || "Failed to create content record" },
            { status: 500 }
          );
        }

        results.push(result);
      } else {
        // Production mode - generate real presigned URLs
        const imageFileRecord = await createFileRecordAction(
          { key: imageKey, filename: `thumb-${item.filename}`, contentType: "image/jpeg", size: 0 },
          session.user.id
        );

        if (!imageFileRecord.success || !imageFileRecord.data) {
          return NextResponse.json(
            { error: imageFileRecord.error || "Failed to create file record" },
            { status: 500 }
          );
        }

        const imageUrl = await generatePresignedPutUrl(imageKey, "image/jpeg");

        const result: { id: string; imageUrl: string; videoUrl?: string } = {
          id: imageFileRecord.data.id,
          imageUrl,
        };

        let contentData: ImageContentData | VideoContentData;

        if (item.type === "video") {
          const videoKey = generatePreviewKey(item.filename, "video");
          const videoFileRecord = await createFileRecordAction(
            { key: videoKey, filename: `preview-${item.filename}`, contentType: item.mime_type, size: 0 },
            session.user.id
          );

          if (!videoFileRecord.success || !videoFileRecord.data) {
            return NextResponse.json(
              { error: videoFileRecord.error || "Failed to create file record" },
              { status: 500 }
            );
          }

          result.videoUrl = await generatePresignedPutUrl(videoKey, item.mime_type);

          contentData = {
            title: item.title,
            description: item.description,
            mime_type: item.mime_type,
            size: item.size,
            file_path: item.file_path,
            preview_image_url: `file:${imageFileRecord.data.id}`,
            preview_video_url: `file:${videoFileRecord.data.id}`,
            video_length: item.video_length!,
          } as VideoContentData;
        } else {
          contentData = {
            title: item.title,
            description: item.description,
            mime_type: item.mime_type,
            size: item.size,
            file_path: item.file_path,
            preview_image_url: `file:${imageFileRecord.data.id}`,
          } as ImageContentData;
        }

        const contentResult = await createContentAction({
          itemId,
          type: item.type === "video" ? "video" : "image",
          data: contentData,
        });

        if (!contentResult.success) {
          return NextResponse.json(
            { error: contentResult.error || "Failed to create content record" },
            { status: 500 }
          );
        }

        results.push(result);
      }
    }

    return NextResponse.json(results, { status: 201 });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Invalid request" },
      { status: 400 }
    );
  }
}
