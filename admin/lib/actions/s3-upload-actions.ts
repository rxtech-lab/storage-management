"use server";

import { PutObjectCommand, DeleteObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { s3Client, S3_BUCKET, S3_PUBLIC_URL } from "@/lib/s3";

export interface PresignedUploadResult {
  uploadUrl: string;
  publicUrl: string;
  key: string;
  expiresAt: string;
}

export interface UploadActionResult {
  success: boolean;
  data?: PresignedUploadResult;
  error?: string;
}

function generateObjectKey(filename: string, folder: string = "items"): string {
  const timestamp = Date.now();
  const randomId = crypto.randomUUID().slice(0, 8);
  const sanitizedFilename = filename.replace(/[^a-zA-Z0-9.-]/g, "_");
  return `${folder}/${timestamp}-${randomId}-${sanitizedFilename}`;
}

function getPublicUrl(key: string): string {
  const baseUrl = S3_PUBLIC_URL.replace(/\/$/, "");
  return `${baseUrl}/${key}`;
}

export async function getImageUploadUrlAction(
  filename: string,
  contentType: string,
  folder: string = "items"
): Promise<UploadActionResult> {
  try {
    if (!contentType.startsWith("image/")) {
      return {
        success: false,
        error: "Only image files are allowed",
      };
    }

    const key = generateObjectKey(filename, folder);

    const command = new PutObjectCommand({
      Bucket: S3_BUCKET,
      Key: key,
      ContentType: contentType,
    });

    const expiresIn = 600;
    const uploadUrl = await getSignedUrl(s3Client, command, { expiresIn });
    const expiresAt = new Date(Date.now() + expiresIn * 1000).toISOString();

    return {
      success: true,
      data: {
        uploadUrl,
        publicUrl: getPublicUrl(key),
        key,
        expiresAt,
      },
    };
  } catch (error) {
    console.error("Failed to generate presigned URL:", error);
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to generate upload URL",
    };
  }
}

export async function deleteImageAction(
  publicUrl: string
): Promise<{ success: boolean; error?: string }> {
  try {
    const baseUrl = S3_PUBLIC_URL.replace(/\/$/, "");
    if (!publicUrl.startsWith(baseUrl)) {
      return { success: false, error: "Invalid image URL" };
    }

    const key = publicUrl.replace(`${baseUrl}/`, "");

    const command = new DeleteObjectCommand({
      Bucket: S3_BUCKET,
      Key: key,
    });

    await s3Client.send(command);

    return { success: true };
  } catch (error) {
    console.error("Failed to delete image:", error);
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to delete image",
    };
  }
}

export async function deleteImagesAction(
  publicUrls: string[]
): Promise<{ success: boolean; failed: string[]; error?: string }> {
  const failed: string[] = [];

  for (const url of publicUrls) {
    const result = await deleteImageAction(url);
    if (!result.success) {
      failed.push(url);
    }
  }

  return {
    success: failed.length === 0,
    failed,
    error: failed.length > 0 ? `Failed to delete ${failed.length} images` : undefined,
  };
}
