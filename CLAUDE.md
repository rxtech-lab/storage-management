# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Dual-platform storage management system:
- **Web Admin** (`/admin`) - Next.js full-stack app with direct Turso/Drizzle database access, provides REST APIs for the mobile app
- **iOS App** (`/RxStorage`) - Swift mobile app with App Clips support for QR code/NFC interactions

## Commands

```bash
# Web Admin (uses Bun)
cd admin
bun run dev       # Development server at http://localhost:3000
bun run build     # Production build
bun run lint      # ESLint
bun run db:push   # Push schema to database
bun run db:studio # Open Drizzle Studio

# iOS App
open RxStorage/RxStorage.xcodeproj
```

## Web Admin Architecture

### Tech Stack
- Next.js 16 (App Router), React 19, TypeScript (strict)
- Turso (SQLite) with Drizzle ORM for direct database access
- Auth.js with OAuth 2.0 OIDC via auth.rxlab.app
- Tailwind CSS v4, shadcn/ui, Framer Motion
- Server Components for frontend rendering
- Mapbox GL for location features
- react-json-schema-form for dynamic forms
- QRCode for QR code generation
- Provides REST APIs consumed by mobile app

### Key Patterns

**Server Actions over REST API** - All CRUD operations use Server Actions in `/lib/actions/` with direct Drizzle queries:
```typescript
// lib/actions/item-actions.ts
"use server";
export async function createItemAction(data) {
  // Direct Drizzle database queries, auto-revalidates cache
}
```

**Direct Database Access** - No external backend API. All database operations use Drizzle ORM with Turso.

**Component Structure**:
- Server Components (default) for data fetching
- Client Components ("use client") only for interactivity

### Directory Structure
```
admin/
├── app/
│   ├── (auth)/              # Public auth routes
│   ├── (dashboard)/         # Protected routes
│   │   ├── items/           # Item management (main entity)
│   │   ├── categories/      # Category management
│   │   ├── locations/       # Location management
│   │   ├── authors/         # Author management
│   │   └── position-schemas/# Custom position schema management
│   ├── preview/[id]/        # Public item preview page
│   └── api/v1/              # REST API for iOS app
├── components/
│   ├── ui/                  # shadcn/ui components
│   ├── forms/               # Entity form components
│   ├── items/               # Item-specific components
│   └── maps/                # Mapbox map components
├── lib/
│   ├── db/                  # Drizzle schema and client
│   │   ├── index.ts         # Database client
│   │   └── schema/          # Table schemas
│   └── actions/             # Server Actions (CRUD)
└── docs/                    # Documentation
```

### Database Schema
| Table | Purpose |
|-------|---------|
| `items` | Main storage items with hierarchy support |
| `categories` | Item categories |
| `locations` | Geographic locations with coordinates |
| `authors` | Item creators/owners |
| `position_schemas` | User-defined JSON schemas for positions |
| `positions` | Item position data |
| `contents` | File/image/video attachments |
| `item_whitelists` | Email whitelist for private items |

### Key Files
| File | Purpose |
|------|---------|
| `auth.ts` | Auth.js OAuth 2.0 config with token refresh |
| `proxy.ts` | Route protection middleware |
| `lib/db/index.ts` | Drizzle client with Turso |
| `lib/db/schema/` | All table schemas |
| `lib/actions/*.ts` | Server Actions for all entities |
| `drizzle.config.ts` | Drizzle configuration |

### Environment Variables

Required in `/admin/.env`:
- `AUTH_SECRET`, `AUTH_ISSUER`, `AUTH_CLIENT_ID`, `AUTH_CLIENT_SECRET` - OAuth config
- `TURSO_DATABASE_URL` - Turso database URL
- `TURSO_AUTH_TOKEN` - Turso auth token
- `NEXT_PUBLIC_MAPBOX_ACCESS_TOKEN` - Mapbox access token

### Features

- Item CRUD with hierarchical parent/child relationships
- Custom position schemas with react-json-schema-form
- Location management with Mapbox integration
- Content attachments (files, images, videos)
- QR code generation for item preview URLs
- Public/private visibility with email whitelist access control
- REST APIs for iOS mobile app consumption
- S3-compatible file upload

## iOS Mobile App Architecture

### Tech Stack
- Swift with SwiftUI
- SwiftData for local persistence
- Communicates with Admin REST APIs

### Two Modes

**Full App Mode** - Requires installation and authentication
- Full CRUD operations on items
- Complete access to all features

**App Clips Mode** - Triggered by QR code or NFC chip scan
- View item details only (no create/update/delete)
- Two access levels:
  - **Public**: No authentication required, view public item info
  - **Private**: Requires authentication to view protected item details

### Directory Structure
```
RxStorage/
├── RxStorage/               # Main app target (full CRUD)
├── RxStorageClips/          # App Clips target (view only)
├── RxStorageTests/          # Unit tests
└── RxStorageUITests/        # UI tests
```

See `MOBILE_APP_DOCUMENTATION.md` for detailed implementation guide.
