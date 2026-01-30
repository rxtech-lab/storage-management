"use server";

import {
  PutObjectCommand,
  DeleteObjectCommand,
  GetObjectCommand,
} from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { s3Client, S3_BUCKET, S3_ENDPOINT, S3_PUBLIC_URL } from "@/lib/s3";
import { createFileRecordAction, getFiles } from "./file-actions";
import { parseFileIds, isFileId } from "@/lib/utils/file-utils";

export interface PresignedUploadResult {
  uploadUrl: string;
  publicUrl: string;
  key: string;
  fileId: number;
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
  if (S3_PUBLIC_URL) {
    const baseUrl = S3_PUBLIC_URL.replace(/\/$/, "");
    return `${baseUrl}/${key}`;
  }
  // Fallback: construct URL from endpoint and bucket
  const endpoint = S3_ENDPOINT.replace(/\/$/, "");
  return `${endpoint}/${S3_BUCKET}/${key}`;
}

function getBaseUrl(): string {
  if (S3_PUBLIC_URL) {
    return S3_PUBLIC_URL.replace(/\/$/, "");
  }
  const endpoint = S3_ENDPOINT.replace(/\/$/, "");
  return `${endpoint}/${S3_BUCKET}`;
}

export async function getImageUploadUrlAction(
  filename: string,
  contentType: string,
  folder: string = "items",
  userId?: string,
  size: number = 0
): Promise<UploadActionResult> {
  try {
    if (!contentType.startsWith("image/")) {
      return {
        success: false,
        error: "Only image files are allowed",
      };
    }

    const key = generateObjectKey(filename, folder);
    const expiresIn = 600;
    const expiresAt = new Date(Date.now() + expiresIn * 1000).toISOString();

    // In E2E mode, return mock data without calling S3
    if (process.env.IS_E2E === "true") {
      const mockKey = `mock/${Date.now()}-${filename.replace(/[^a-zA-Z0-9.-]/g, "_")}`;

      // Create file record in database
      const fileRecord = await createFileRecordAction({
        key: mockKey,
        filename,
        contentType,
        size,
      }, userId);

      if (!fileRecord.success || !fileRecord.data) {
        return { success: false, error: fileRecord.error || "Failed to create file record" };
      }

      return {
        success: true,
        data: {
          uploadUrl: `https://mock-s3.example.com/upload/${mockKey}`,
          publicUrl: `https://mock-s3.example.com/${mockKey}`,
          key: mockKey,
          fileId: fileRecord.data.id,
          expiresAt,
        },
      };
    }

    const command = new PutObjectCommand({
      Bucket: S3_BUCKET,
      Key: key,
      ContentType: contentType,
    });

    const uploadUrl = await getSignedUrl(s3Client, command, { expiresIn });

    // Create file record in database
    const fileRecord = await createFileRecordAction({
      key,
      filename,
      contentType,
      size,
    }, userId);

    if (!fileRecord.success || !fileRecord.data) {
      return { success: false, error: fileRecord.error || "Failed to create file record" };
    }

    return {
      success: true,
      data: {
        uploadUrl,
        publicUrl: getPublicUrl(key),
        key,
        fileId: fileRecord.data.id,
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
    const baseUrl = getBaseUrl();
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

// --- Signed URL for GET (viewing) ---

export interface SignedUrlResult {
  originalUrl: string;
  signedUrl: string;
  expiresAt: string;
}

function getKeyFromPublicUrl(publicUrl: string): string | null {
  const baseUrl = getBaseUrl();
  if (!publicUrl.startsWith(baseUrl)) {
    return null;
  }
  return publicUrl.replace(`${baseUrl}/`, "");
}

export async function signImageUrlAction(
  publicUrl: string,
  expiresIn: number = 3600
): Promise<{ success: boolean; data?: SignedUrlResult; error?: string }> {
  try {
    const key = getKeyFromPublicUrl(publicUrl);
    if (!key) {
      return { success: false, error: "Invalid image URL" };
    }

    const command = new GetObjectCommand({
      Bucket: S3_BUCKET,
      Key: key,
    });

    const signedUrl = await getSignedUrl(s3Client, command, { expiresIn });
    const expiresAt = new Date(Date.now() + expiresIn * 1000).toISOString();

    return {
      success: true,
      data: {
        originalUrl: publicUrl,
        signedUrl,
        expiresAt,
      },
    };
  } catch (error) {
    console.error("Failed to sign image URL:", error);
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to sign URL",
    };
  }
}

export async function signImageUrlsAction(
  publicUrls: string[],
  expiresIn: number = 3600
): Promise<{
  success: boolean;
  data?: SignedUrlResult[];
  failed?: string[];
  error?: string;
}> {
  if (publicUrls.length === 0) {
    return { success: true, data: [] };
  }

  const results: SignedUrlResult[] = [];
  const failed: string[] = [];

  const promises = publicUrls.map(async (url) => {
    const result = await signImageUrlAction(url, expiresIn);
    if (result.success && result.data) {
      return { success: true as const, data: result.data };
    }
    return { success: false as const, url };
  });

  const resolved = await Promise.all(promises);

  resolved.forEach((result) => {
    if (result.success) {
      results.push(result.data);
    } else {
      failed.push(result.url);
    }
  });

  return {
    success: failed.length === 0,
    data: results,
    failed: failed.length > 0 ? failed : undefined,
    error: failed.length > 0 ? `Failed to sign ${failed.length} URLs` : undefined,
  };
}

// --- Sign URLs by File IDs ---

export interface SignedFileUrlResult {
  fileId: number;
  signedUrl: string;
  expiresAt: string;
}

/**
 * Sign S3 URLs for files by their database IDs
 * Returns signed URLs mapped to file IDs
 */
export async function signFileUrlsAction(
  fileIds: number[],
  expiresIn: number = 3600
): Promise<{
  success: boolean;
  data?: SignedFileUrlResult[];
  failed?: number[];
  error?: string;
}> {
  if (fileIds.length === 0) {
    return { success: true, data: [] };
  }

  // In E2E mode, return mock signed URLs
  if (process.env.IS_E2E === "true") {
    const files = await getFiles(fileIds);
    const expiresAt = new Date(Date.now() + expiresIn * 1000).toISOString();
    return {
      success: true,
      data: files.map((f) => ({
        fileId: f.id,
        signedUrl: `https://mock-s3.example.com/signed/${f.key}?expires=${expiresAt}`,
        expiresAt,
      })),
    };
  }

  const files = await getFiles(fileIds);
  const results: SignedFileUrlResult[] = [];
  const failed: number[] = [];

  const promises = files.map(async (file) => {
    try {
      const command = new GetObjectCommand({
        Bucket: S3_BUCKET,
        Key: file.key,
      });

      const signedUrl = await getSignedUrl(s3Client, command, { expiresIn });
      const expiresAt = new Date(Date.now() + expiresIn * 1000).toISOString();

      return {
        success: true as const,
        data: { fileId: file.id, signedUrl, expiresAt },
      };
    } catch (error) {
      console.error(`Failed to sign URL for file ${file.id}:`, error);
      return { success: false as const, fileId: file.id };
    }
  });

  const resolved = await Promise.all(promises);

  resolved.forEach((result) => {
    if (result.success) {
      results.push(result.data);
    } else {
      failed.push(result.fileId);
    }
  });

  return {
    success: failed.length === 0,
    data: results,
    failed: failed.length > 0 ? failed : undefined,
    error: failed.length > 0 ? `Failed to sign ${failed.length} file URLs` : undefined,
  };
}

/**
 * Sign images from an images array that may contain both file IDs and legacy URLs
 * Returns an array of signed URLs in the same order as input
 */
export async function signImagesArray(
  images: string[],
  expiresIn: number = 3600
): Promise<string[]> {
  if (images.length === 0) {
    return [];
  }

  const signedUrls: string[] = new Array(images.length);
  const fileIdIndices: { index: number; fileId: number }[] = [];
  const urlIndices: { index: number; url: string }[] = [];

  // Separate file IDs and legacy URLs
  images.forEach((image, index) => {
    if (isFileId(image)) {
      const fileId = parseInt(image.substring(5), 10);
      if (!isNaN(fileId)) {
        fileIdIndices.push({ index, fileId });
      }
    } else {
      urlIndices.push({ index, url: image });
    }
  });

  // Sign file IDs
  if (fileIdIndices.length > 0) {
    const fileIds = fileIdIndices.map((f) => f.fileId);
    const result = await signFileUrlsAction(fileIds, expiresIn);
    if (result.success && result.data) {
      const signedMap = new Map(result.data.map((r) => [r.fileId, r.signedUrl]));
      for (const { index, fileId } of fileIdIndices) {
        signedUrls[index] = signedMap.get(fileId) || "";
      }
    }
  }

  // Sign legacy URLs
  if (urlIndices.length > 0) {
    const urls = urlIndices.map((u) => u.url);
    const result = await signImageUrlsAction(urls, expiresIn);
    if (result.success && result.data) {
      const signedMap = new Map(result.data.map((r) => [r.originalUrl, r.signedUrl]));
      for (const { index, url } of urlIndices) {
        signedUrls[index] = signedMap.get(url) || url;
      }
    }
  }

  return signedUrls;
}
