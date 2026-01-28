# Features Guide

## Item Management

### Creating Items

Items are the core entity of the storage management system. Each item can have:

- **Title** (required) - The name of the item
- **Description** - Detailed description
- **Category** - Classification (can be created inline)
- **Location** - Geographic location with coordinates (can be created inline)
- **Author** - Creator/owner of the item (can be created inline)
- **Parent Item** - For hierarchical organization
- **Price** - Optional monetary value
- **Visibility** - Public or private
- **Images** - Multiple image URLs

### Hierarchical Organization

Items support parent-child relationships for organizing items in trees:

- Set a parent item when creating/editing an item
- View child items in the "Children" tab on item detail pages
- Use the tree view on the items list page to see the full hierarchy
- Navigate through the tree structure easily

### Views

The item list page supports multiple view modes:

- **Grid View** - Card-based layout with images
- **List View** - Compact table-style layout
- **Tree View** - Hierarchical tree structure

### Filtering

Filter items by:
- Category
- Location
- Author
- Visibility (public/private)
- Search by title/description

---

## Position Schemas

Position schemas allow you to define custom structures for tracking where items are physically located within a storage system.

### Creating a Schema

1. Go to Position Schemas in the sidebar
2. Click "New Position Schema"
3. Enter a name (e.g., "Bookshelf Position")
4. Define the JSON Schema using the editor

Example schema for a bookshelf:
```json
{
  "type": "object",
  "properties": {
    "shelf": {
      "type": "integer",
      "title": "Shelf Number",
      "minimum": 1
    },
    "row": {
      "type": "integer",
      "title": "Row",
      "minimum": 1
    },
    "position": {
      "type": "integer",
      "title": "Position from Left",
      "minimum": 1
    }
  },
  "required": ["shelf", "row", "position"]
}
```

### Using Position Schemas

1. Open an item's detail page
2. Go to the "Position" tab
3. Select a position schema from the dropdown
4. Fill in the position data using the auto-generated form
5. Save the position

---

## Location Management

### Adding Locations

Locations track geographic positions using latitude/longitude coordinates:

1. Go to Locations in the sidebar
2. Click "New Location"
3. Enter a title
4. Either:
   - Click on the map to select a point
   - Enter coordinates manually

### Using Locations

- Assign locations to items during creation/editing
- View item locations on the map in the detail view
- Filter items by location

---

## Content Management

Items can have attached content of three types:

### Files
- Any file type
- Stores: title, description, MIME type, size, file path

### Images
- Image files with preview support
- Stores: all file properties + preview image URL

### Videos
- Video files with duration tracking
- Stores: all image properties + video length, preview video URL

### Managing Content

1. Open an item's detail page
2. Go to the "Contents" tab
3. Click "Add Content"
4. Select the content type
5. Fill in the metadata
6. Save

---

## Visibility & Access Control

### Public Items

- Accessible to anyone via the preview URL
- No authentication required
- QR codes link directly to preview

### Private Items

- Require authentication to view
- Access controlled by email whitelist
- Only whitelisted emails can view the item

### Managing Whitelist

1. Open an item's detail page
2. Go to the "Whitelist" tab
3. Add individual emails or bulk add (one per line)
4. Remove emails as needed

---

## QR Codes

Generate QR codes that link to the public preview page:

1. Open an item's detail page
2. Click "Generate QR Code" button
3. Download the QR code image
4. Or copy the preview URL directly

The QR code encodes: `https://your-domain.com/preview/{itemId}`

---

## Preview Page

The preview page (`/preview/{id}`) displays item details based on visibility:

### Public Items
- Displayed immediately without authentication
- Shows: title, description, images, location map, contents

### Private Items
1. Redirects to authentication if not logged in
2. After auth, checks if user's email is whitelisted
3. If whitelisted: shows full item details
4. If not whitelisted: shows access denied message

---

## Dashboard

The dashboard provides an overview of your storage system:

- Total items count
- Category distribution
- Location distribution
- Recent items
- Public vs private items

---

## Search

Use the global search (Cmd/Ctrl + K) to quickly find items:

- Searches by title
- Shows category in results
- Indicates visibility status
- Click to navigate to item detail
