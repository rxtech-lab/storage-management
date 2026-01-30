# File Upload API Documentation

Base URL: `/api/v1`

This document describes the file upload system for managing images attached to items.

## Overview

The upload system uses a two-step process:
1. **Get presigned URL** - Creates a file record and returns a presigned S3 URL
2. **Upload to S3** - Client uploads directly to S3 using the presigned URL
3. **Associate with item** - Include file IDs when creating/updating items

File IDs are stored in the format `file:{id}` (e.g., `file:123`). API responses automatically convert these to signed URLs.

---

## Endpoints

### Get Presigned Upload URL

```
POST /upload/presigned
```

Creates a file record in the database and returns a presigned URL for uploading to S3.

**Request Body:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `filename` | string | Yes | Original filename |
| `contentType` | string | Yes | MIME type (must start with `image/`) |
| `size` | integer | No | File size in bytes |

**Example Request:**
```json
{
  "filename": "photo.jpg",
  "contentType": "image/jpeg",
  "size": 102400
}
```

**Response (201):**
```json
{
  "uploadUrl": "https://s3.example.com/bucket/items/123-abc-photo.jpg?X-Amz-Signature=...",
  "publicUrl": "https://s3.example.com/bucket/items/123-abc-photo.jpg",
  "key": "items/123-abc-photo.jpg",
  "fileId": 1,
  "expiresAt": "2026-01-30T03:00:00.000Z"
}
```

**Error Responses:**
- `400` - Invalid content type (only images allowed) or missing required fields
- `401` - Unauthorized

---

## Using File IDs with Items

### Create Item with Images

```
POST /items
```

**Request Body:**
```json
{
  "title": "My Item",
  "description": "Item with uploaded images",
  "visibility": "public",
  "images": ["file:1", "file:2"]
}
```

**Response (201):**
```json
{
  "id": 1,
  "title": "My Item",
  "description": "Item with uploaded images",
  "visibility": "public",
  "images": [
    "https://s3.example.com/signed-url-1?expires=...",
    "https://s3.example.com/signed-url-2?expires=..."
  ]
}
```

> **Note:** The `images` field in the response contains signed URLs, not the raw `file:` references.

### Update Item Images

```
PUT /items/{id}
```

**Request Body:**
```json
{
  "images": ["file:1", "file:3"]
}
```

When updating images:
- New file IDs are validated and associated with the item
- Removed file IDs are disassociated from the item
- The response contains signed URLs

---

## Verification Flow

When creating or updating an item with file IDs, the following validations occur:

```
┌─────────────────────────────────────────────────────────┐
│  1. Parse File IDs                                      │
│     Extract numeric IDs from "file:N" format            │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│  2. Validate Ownership                                  │
│     - File must exist in database                       │
│     - File must belong to the requesting user           │
│     ❌ 400 "Invalid or unauthorized file IDs: N"        │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│  3. Validate S3 Existence                               │
│     - HeadObject command to verify file was uploaded    │
│     - Skipped in E2E test mode                          │
│     ❌ 400 "Files not found in storage: N"              │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│  4. Create/Update Item                                  │
│     - Store file IDs in images array                    │
│     - Associate files with item in database             │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│  5. Sign URLs for Response                              │
│     - Convert "file:N" to signed S3 URLs                │
│     - URLs expire after 1 hour                          │
└─────────────────────────────────────────────────────────┘
```

---

## Database Schema

The `upload_files` table tracks all uploaded files:

```sql
CREATE TABLE upload_files (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL,           -- File owner
  key TEXT NOT NULL,               -- S3 object key
  filename TEXT NOT NULL,          -- Original filename
  content_type TEXT NOT NULL,      -- MIME type
  size INTEGER NOT NULL,           -- File size in bytes
  item_id INTEGER,                 -- Associated item (nullable)
  created_at INTEGER NOT NULL,
  FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE SET NULL
);
```

---

## Client Implementation Example

### JavaScript/TypeScript

```typescript
// Step 1: Get presigned URL
const presignedResponse = await fetch('/api/v1/upload/presigned', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  },
  body: JSON.stringify({
    filename: file.name,
    contentType: file.type,
    size: file.size
  })
});

const { uploadUrl, fileId } = await presignedResponse.json();

// Step 2: Upload directly to S3
await fetch(uploadUrl, {
  method: 'PUT',
  headers: {
    'Content-Type': file.type
  },
  body: file
});

// Step 3: Create item with file ID
const itemResponse = await fetch('/api/v1/items', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  },
  body: JSON.stringify({
    title: 'My Item',
    visibility: 'public',
    images: [`file:${fileId}`]
  })
});

const item = await itemResponse.json();
// item.images contains signed URLs ready for display
```

### Swift (iOS)

```swift
// Step 1: Get presigned URL
struct PresignedResponse: Codable {
    let uploadUrl: String
    let fileId: Int
    let key: String
    let expiresAt: String
}

let presignedURL = try await apiClient.post(
    "/upload/presigned",
    body: ["filename": "photo.jpg", "contentType": "image/jpeg", "size": imageData.count]
) as PresignedResponse

// Step 2: Upload to S3
var request = URLRequest(url: URL(string: presignedURL.uploadUrl)!)
request.httpMethod = "PUT"
request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
request.httpBody = imageData
try await URLSession.shared.data(for: request)

// Step 3: Create item with file ID
let item = try await apiClient.post("/items", body: [
    "title": "My Item",
    "visibility": "public",
    "images": ["file:\(presignedURL.fileId)"]
])
```

---

## File Deletion

When an item is deleted, all associated files are automatically:
1. Deleted from S3 storage
2. Removed from the `upload_files` table

Files that are disassociated from items (via update) remain in storage but have their `item_id` set to `null`.

---

## Error Codes

| Status | Error | Description |
|--------|-------|-------------|
| 400 | `Only image files are allowed` | contentType must start with `image/` |
| 400 | `filename is required` | Missing filename in request |
| 400 | `contentType is required` | Missing contentType in request |
| 400 | `Invalid or unauthorized file IDs: N` | File doesn't exist or belongs to another user |
| 400 | `Files not found in storage: N` | File record exists but not uploaded to S3 |
| 401 | `Unauthorized` | Missing or invalid authentication |

---

## E2E Testing

In E2E test mode (`IS_E2E=true`):
- Presigned URLs return mock S3 URLs (`https://mock-s3.example.com/...`)
- S3 existence validation is skipped
- Signed URLs use mock format for verification

Example mock response:
```json
{
  "uploadUrl": "https://mock-s3.example.com/upload/mock/123-photo.jpg",
  "fileId": 1,
  "key": "mock/123-photo.jpg"
}
```
