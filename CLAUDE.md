# CLAUDE.md

**You don't have access to cd cmd, please write a script in the root and run it when command needs cd**

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
./build.sh        # Build for iOS Simulator (Debug config)
open RxStorage/RxStorage.xcodeproj  # Open in Xcode
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

| Table              | Purpose                                   |
| ------------------ | ----------------------------------------- |
| `items`            | Main storage items with hierarchy support |
| `categories`       | Item categories                           |
| `locations`        | Geographic locations with coordinates     |
| `authors`          | Item creators/owners                      |
| `position_schemas` | User-defined JSON schemas for positions   |
| `positions`        | Item position data                        |
| `contents`         | File/image/video attachments              |
| `item_whitelists`  | Email whitelist for private items         |

### Key Files

| File                | Purpose                                     |
| ------------------- | ------------------------------------------- |
| `auth.ts`           | Auth.js OAuth 2.0 config with token refresh |
| `proxy.ts`          | Route protection middleware                 |
| `lib/db/index.ts`   | Drizzle client with Turso                   |
| `lib/db/schema/`    | All table schemas                           |
| `lib/actions/*.ts`  | Server Actions for all entities             |
| `drizzle.config.ts` | Drizzle configuration                       |

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

- Swift with SwiftUI (iOS 17+)
- @Observable macro for state management (no SwiftData)
- OAuth 2.0 PKCE authentication via auth.rxlab.app
- Bearer token authentication for API requests
- RxStorageCore SPM framework (shared between main app and App Clips)
- NavigationSplitView for adaptive iPad/iPhone layout

### Two Modes

**Full App Mode** - Requires installation and OAuth authentication

- Full CRUD operations on items
- Complete access to all features
- Pull-to-refresh on lists

**App Clips Mode** - Triggered by QR code or NFC chip scan

- View item details only (no create/update/delete)
- Two access levels:
  - **Public**: No authentication required, view public item info
  - **Private**: Requires authentication to view protected item details

### Directory Structure

```
RxStorage/
├── RxStorage/                      # Main app target
│   ├── Config/                     # Build configurations
│   │   ├── Debug.xcconfig          # Dev environment (localhost)
│   │   ├── Release.xcconfig        # Prod environment
│   │   └── Secrets.xcconfig        # OAuth client IDs (gitignored)
│   ├── Info.plist                  # Uses $(VARIABLE) substitution
│   ├── ContentView.swift           # Auth state + Login/Main view
│   └── RxStorageApp.swift          # App entry point
├── RxStorageCore/                  # SPM framework (shared code)
│   └── Sources/RxStorageCore/
│       ├── Models/                 # Codable models (API-only)
│       ├── Networking/             # APIClient + Services
│       ├── Authentication/         # OAuthManager + TokenStorage
│       ├── ViewModels/             # @Observable view models
│       ├── Views/                  # SwiftUI views
│       └── Configuration/          # AppConfiguration
├── RxStorageClips/                 # App Clips target
├── RxStorageTests/                 # Unit tests
└── RxStorageUITests/               # UI tests
```

### Building the iOS App

**Prerequisites:**

1. Xcode 15+ installed
2. iOS Simulator or device

**Initial Setup:**

```bash
# 1. Create Secrets.xcconfig from example
cd RxStorage/RxStorage/Config
cp Secrets.xcconfig.example Secrets.xcconfig

# 2. Edit Secrets.xcconfig with your OAuth client IDs
# AUTH_CLIENT_ID_DEV = client_XXXXX
# AUTH_CLIENT_ID_PROD = client_XXXXX
```

**Build Commands:**

```bash
# From repository root
./build.sh                    # Build for simulator (Debug config)

# Or use Xcode directly
open RxStorage/RxStorage.xcodeproj
# Cmd+B to build, Cmd+R to run
```

**Build Script Details:**
The `build.sh` script uses xcodebuild with:

- Scheme: RxStorage
- Configuration: Debug
- Destination: iPhone 17, iOS 26.2 Simulator
- SDK: iphonesimulator

### Configuration System

**xcconfig Files** - Environment-based configuration:

- `Debug.xcconfig` - Development (localhost API)
- `Release.xcconfig` - Production (rxlab.app API)
- `Secrets.xcconfig` - OAuth client IDs (gitignored, must create locally)

**Info.plist Variable Substitution:**

```xml
<key>API_BASE_URL</key>
<string>$(API_BASE_URL)</string>
<key>AUTH_CLIENT_ID</key>
<string>$(AUTH_CLIENT_ID)</string>
```

Values are resolved at build time from xcconfig files.

**Reading Configuration in Swift:**

```swift
// AppConfiguration.swift reads from Info.plist
let config = AppConfiguration.shared
let apiBaseURL = config.apiBaseURL  // "http://localhost:3000" in Debug
let clientID = config.authClientID  // From Secrets.xcconfig
```

### Authentication Flow

**OAuth 2.0 PKCE Flow:**

1. User taps "Sign in with RxLab" in LoginView
2. OAuthManager launches ASWebAuthenticationSession
3. User authenticates at auth.rxlab.app
4. Callback to `rxstorage://oauth/callback` with auth code
5. Exchange code for access/refresh tokens (no client secret needed)
6. Store tokens securely in Keychain via TokenStorage
7. Inject Bearer token in all API requests via APIClient

**URL Scheme Registration:**
Registered in `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>rxstorage</string>
    </array>
  </dict>
</array>
```

**Bearer Token Authentication:**
The iOS app uses Bearer tokens for API authentication:

```swift
// APIClient automatically adds header to all requests
Authorization: Bearer <access_token>
```

Backend supports both session-based auth (web) and Bearer tokens (mobile) in `/api/v1` routes.

### Backend Requirements for iOS App

The web admin API must support Bearer token authentication for mobile clients:

**API Route Pattern:**

```typescript
// app/api/v1/items/route.ts
export async function GET(request: NextRequest) {
  const session = await getSession(request); // Supports Bearer token
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  const items = await getItems(filters);
  return NextResponse.json(items); // Direct array
}
```

**Middleware Configuration:**
`proxy.ts` must exclude `/api/v1` routes from session-based auth:

```typescript
const publicPaths = ["/login", "/api/auth", "/preview", "/api/v1"];
```

This allows API routes to handle their own authentication (Bearer token validation).

**Token Verification:**
The `getSession()` helper in `lib/auth-helper.ts` checks:

1. Bearer token in Authorization header (for mobile)
2. Falls back to session cookie (for web)

### Key Features

- **OAuth Login** - ASWebAuthenticationSession with PKCE (no client secret)
- **Bearer Token Auth** - Secure API authentication via Keychain
- **Pull to Refresh** - Available on all list views including empty states
- **NavigationSplitView** - Three-column layout on iPad, stack on iPhone
- **QR Code Support** - Generate, scan, print QR codes for items
- **App Clips** - View-only mode triggered by QR/NFC
- **Hierarchical Items** - Parent-child relationships
- **Dynamic Forms** - JSON schema-based position forms
- **Inline Creation** - Create related entities (categories, locations) during item creation

### UI Patterns

**Confirmation Dialogs** - Use the custom `.confirmationDialog` modifier for delete and destructive actions:

```swift
// For delete confirmations
.confirmationDialog(
    title: "Delete Item",
    message: "Are you sure you want to delete \"\(itemToDelete?.title ?? "")\"? This action cannot be undone.",
    isPresented: $showDeleteConfirmation,
    onConfirm: {
        // Perform delete action
    },
    onCancel: { itemToDelete = nil }
)

// For sign out confirmations
.signOutConfirmation(isPresented: $showSignOutConfirmation) {
    // Perform sign out action
}
```

See `Views/Modifiers/ConfirmationDialogModifier.swift` for the implementation.

### Testing

**Run Unit Tests:**

```bash
# From Xcode: Cmd+U
# Or via CLI:
xcodebuild test \
  -project RxStorage/RxStorage.xcodeproj \
  -scheme RxStorage \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

**Run ui tests**

```bash
./scripts/ios-ui-test.sh
```

**Manual Testing Checklist:**

1. OAuth login flow (test token storage)
2. List items (pull-to-refresh, search, filters)
3. View item detail (hierarchy, contents, QR code)
4. Create/edit/delete items
5. Generate and scan QR codes
6. Test on iPad (NavigationSplitView)
7. Test App Clips activation via QR code

### Team Setup

**New Developer Onboarding:**

1. Clone repository
2. Install dependencies: `cd admin && bun install`
3. Copy `RxStorage/RxStorage/Config/Secrets.xcconfig.example` to `Secrets.xcconfig`
4. Contact team for OAuth client IDs and add to `Secrets.xcconfig`
5. Open `RxStorage/RxStorage.xcodeproj` in Xcode
6. Build and run (Cmd+R)

See `RxStorage/RxStorage/Config/XCCONFIG_SETUP.md` for detailed configuration guide.

## Build and test

Since you don't have access to cd, run `scripts/ios-test.sh` and `scripts/ios-build.sh` script to build and test the ios mobile app which includes testing the app and its packages.

## OpenAPI

Apis are defined in openapi format and use codegen for both frontend mobile app and backend. When updating the backend api, run `./scripts/ios-update-openapi.sh` script to regenerate clients. This will regenerate both backend and frontend code. Use this always!
