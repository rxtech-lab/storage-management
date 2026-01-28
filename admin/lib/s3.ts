import { S3Client } from "@aws-sdk/client-s3";

// S3-compatible client (works with AWS S3, Cloudflare R2, MinIO, etc.)
export const s3Client = new S3Client({
  region: process.env.S3_REGION || "auto",
  endpoint: process.env.S3_ENDPOINT,
  credentials: {
    accessKeyId: process.env.S3_ACCESS_KEY_ID!,
    secretAccessKey: process.env.S3_SECRET_ACCESS_KEY!,
  },
});

export const S3_BUCKET = process.env.S3_BUCKET!;
export const S3_ENDPOINT = process.env.S3_ENDPOINT!;
// Optional: If not set, falls back to endpoint/bucket/key format
export const S3_PUBLIC_URL = process.env.S3_PUBLIC_URL;
