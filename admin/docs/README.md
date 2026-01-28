# Storage Management System - Admin

A Next.js full-stack admin application for managing storage items with hierarchical organization, location tracking, and visibility controls.

## Quick Start

```bash
# Install dependencies
bun install

# Set up environment variables
cp .env.example .env
# Edit .env with your Turso and Mapbox credentials

# Run database migrations
bun run db:push

# Start development server
bun run dev
```

## Features

- **Item Management** - CRUD operations for storage items with categories, locations, and authors
- **Hierarchical Items** - Parent/child relationships for organizing items in trees
- **Position Schemas** - User-defined JSON schemas for custom position tracking
- **Location Tracking** - Mapbox integration for geographic location management
- **QR Codes** - Generate QR codes linking to public preview pages
- **Visibility Control** - Public/private items with email whitelist access
- **Content Management** - Attach files, images, and videos to items
- **REST API** - Full API for iOS mobile app consumption

## Documentation

- [Features Guide](./FEATURES.md) - Detailed feature documentation
- [API Reference](./API.md) - REST API documentation
- [OpenAPI Spec](./openapi.yaml) - OpenAPI 3.0 specification

## Tech Stack

- **Framework**: Next.js 16 (App Router)
- **Language**: TypeScript (strict mode)
- **Database**: Turso (SQLite) with Drizzle ORM
- **Auth**: Auth.js with OAuth 2.0 OIDC
- **UI**: Tailwind CSS v4, shadcn/ui, Framer Motion
- **Maps**: Mapbox GL / react-map-gl
- **Forms**: react-json-schema-form (@rjsf)

## Environment Variables

| Variable | Description |
|----------|-------------|
| `TURSO_DATABASE_URL` | Turso database URL |
| `TURSO_AUTH_TOKEN` | Turso auth token |
| `NEXT_PUBLIC_MAPBOX_ACCESS_TOKEN` | Mapbox access token |
| `AUTH_SECRET` | Auth.js secret |
| `AUTH_ISSUER` | OAuth 2.0 issuer URL |
| `AUTH_CLIENT_ID` | OAuth client ID |
| `AUTH_CLIENT_SECRET` | OAuth client secret |

## Project Structure

```
admin/
├── app/
│   ├── (auth)/              # Public auth routes
│   ├── (dashboard)/         # Protected routes
│   │   ├── items/           # Item management
│   │   ├── categories/      # Category management
│   │   ├── locations/       # Location management
│   │   ├── authors/         # Author management
│   │   └── position-schemas/# Position schema management
│   ├── preview/[id]/        # Public item preview
│   └── api/v1/              # REST API endpoints
├── components/
│   ├── ui/                  # shadcn/ui components
│   ├── forms/               # Entity forms
│   ├── items/               # Item-specific components
│   └── maps/                # Map components
├── lib/
│   ├── db/                  # Drizzle schema and client
│   └── actions/             # Server Actions
└── docs/                    # Documentation
```

## License

Private - All rights reserved.
