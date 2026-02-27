# REST API Documentation

Base URL: `/api/v1`

All endpoints (except `/preview/{id}` and `/openapi.json`) require Bearer token authentication.

## Authentication

Include the Bearer token in the Authorization header:

```
Authorization: Bearer <your-token>
```

---

## Items

### List Items

```
GET /items
```

Query Parameters:
| Parameter | Type | Description |
|-----------|------|-------------|
| `categoryId` | integer | Filter by category |
| `locationId` | integer | Filter by location |
| `authorId` | integer | Filter by author |
| `parentId` | string | Filter by parent item (use "null" for root items) |
| `visibility` | string | Filter by visibility: "public" or "private" |
| `search` | string | Search in title and description |

Response:
```json
{
  "data": [
    {
      "id": 1,
      "title": "Item Title",
      "description": "Description",
      "categoryId": 1,
      "locationId": 1,
      "authorId": 1,
      "parentId": null,
      "price": "19.99",
      "visibility": "public",
      "images": ["https://..."],
      "createdAt": "2024-01-01T00:00:00.000Z",
      "updatedAt": "2024-01-01T00:00:00.000Z",
      "category": { "id": 1, "name": "Category" },
      "location": { "id": 1, "title": "Location" },
      "author": { "id": 1, "name": "Author" }
    }
  ]
}
```

### Create Item

```
POST /items
```

Request Body:
```json
{
  "title": "Item Title",
  "description": "Description",
  "categoryId": 1,
  "locationId": 1,
  "authorId": 1,
  "parentId": null,
  "price": 19.99,
  "visibility": "public",
  "images": ["https://..."]
}
```

### Get Item

```
GET /items/{id}
```

### Update Item

```
PUT /items/{id}
```

Request Body: Same as create

### Delete Item

```
DELETE /items/{id}
```

### Get Item Children

```
GET /items/{id}/children
```

Returns all direct children of the specified item.

### Get Item QR Code

```
GET /items/{id}/qr
```

Response:
```json
{
  "data": {
    "itemId": 1,
    "previewUrl": "https://your-domain.com/preview/item?id=1",
    "qrCodeDataUrl": "data:image/png;base64,..."
  }
}
```

---

## Categories

### List Categories

```
GET /categories
```

### Create Category

```
POST /categories
```

Request Body:
```json
{
  "name": "Category Name",
  "description": "Description"
}
```

### Get Category

```
GET /categories/{id}
```

### Update Category

```
PUT /categories/{id}
```

### Delete Category

```
DELETE /categories/{id}
```

---

## Locations

### List Locations

```
GET /locations
```

### Create Location

```
POST /locations
```

Request Body:
```json
{
  "title": "Location Title",
  "latitude": 37.7749,
  "longitude": -122.4194
}
```

### Get Location

```
GET /locations/{id}
```

### Update Location

```
PUT /locations/{id}
```

### Delete Location

```
DELETE /locations/{id}
```

---

## Authors

### List Authors

```
GET /authors
```

### Create Author

```
POST /authors
```

Request Body:
```json
{
  "name": "Author Name",
  "bio": "Author biography"
}
```

### Get Author

```
GET /authors/{id}
```

### Update Author

```
PUT /authors/{id}
```

### Delete Author

```
DELETE /authors/{id}
```

---

## Position Schemas

### List Position Schemas

```
GET /position-schemas
```

### Create Position Schema

```
POST /position-schemas
```

Request Body:
```json
{
  "name": "Schema Name",
  "schema": {
    "type": "object",
    "properties": {
      "shelf": { "type": "integer" }
    }
  }
}
```

### Get Position Schema

```
GET /position-schemas/{id}
```

### Update Position Schema

```
PUT /position-schemas/{id}
```

### Delete Position Schema

```
DELETE /position-schemas/{id}
```

---

## Preview

### Get Item Preview

```
GET /preview/{id}
```

**No authentication required for public items.**

For private items:
- Returns 401 if not authenticated
- Returns 403 if authenticated but not whitelisted
- Returns 200 with item data if authenticated and whitelisted

Response (success):
```json
{
  "data": {
    "id": 1,
    "title": "Item Title",
    "description": "Description",
    "visibility": "public",
    "images": ["https://..."],
    "category": { "id": 1, "name": "Category" },
    "location": {
      "id": 1,
      "title": "Location",
      "latitude": 37.7749,
      "longitude": -122.4194
    },
    "author": { "id": 1, "name": "Author" },
    "contents": [
      {
        "id": 1,
        "type": "image",
        "data": { "title": "Photo", "file_path": "https://..." }
      }
    ]
  }
}
```

Response (private, not authenticated):
```json
{
  "error": "Authentication required",
  "visibility": "private"
}
```

Response (private, not whitelisted):
```json
{
  "error": "Access denied",
  "visibility": "private"
}
```

---

## OpenAPI Specification

```
GET /openapi.json
```

Returns the OpenAPI 3.0 specification for the API.

---

## Error Responses

All endpoints return errors in the following format:

```json
{
  "error": "Error message"
}
```

Common HTTP status codes:
- `400` - Bad Request (invalid input)
- `401` - Unauthorized (missing or invalid auth)
- `403` - Forbidden (not allowed to access resource)
- `404` - Not Found
- `500` - Internal Server Error
