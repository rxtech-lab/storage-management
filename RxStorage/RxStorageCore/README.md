# RxStorageCore

Swift Package for the RxStorage iOS app - shared code between main app and App Clips.

## Overview

RxStorageCore is a Swift Package Manager (SPM) module containing all the shared business logic, networking, authentication, and UI components for the RxStorage iOS application.

## Structure

```
RxStorageCore/
├── Package.swift                     # SPM manifest
├── Sources/
│   └── RxStorageCore/
│       ├── Configuration/            # App configuration
│       │   └── AppConfiguration.swift
│       ├── Authentication/           # OAuth + token storage
│       │   ├── TokenStorage.swift
│       │   └── OAuthManager.swift
│       ├── Networking/              # API client + endpoints
│       │   ├── APIClient.swift
│       │   ├── APIEndpoint.swift
│       │   └── APIError.swift
│       ├── Models/                  # Data models (to be created)
│       ├── ViewModels/              # View models (to be created)
│       ├── Views/                   # SwiftUI views (to be created)
│       └── Utilities/               # Helper extensions
└── Tests/
    └── RxStorageCoreTests/          # Unit tests (to be created)
```

## Requirements

- iOS 17.0+
- Swift 5.9+

## Installation

### Via Xcode

1. Open `RxStorage.xcodeproj` in Xcode
2. File → Add Package Dependencies
3. Choose "Add Local..."
4. Navigate to `/RxStorage/RxStorageCore`
5. Add the package to both **RxStorage** and **RxStorageClips** targets

### Manual Setup

1. Drag the `RxStorageCore` folder into your Xcode project
2. In project settings, add `RxStorageCore` to target dependencies
3. Import in Swift files: `import RxStorageCore`

## Features

### ✅ Configuration
- **AppConfiguration** - Reads API URLs and OAuth settings from Info.plist
- Environment-based configuration (Debug/Release)

### ✅ Authentication
- **TokenStorage** - Secure Keychain wrapper for OAuth tokens
- **OAuthManager** - OAuth 2.0 PKCE flow with ASWebAuthenticationSession
- Automatic token refresh
- User session management

### ✅ Networking
- **APIClient** - HTTP client with Bearer token injection
- **APIEndpoint** - Type-safe endpoint definitions
- **APIError** - Comprehensive error handling
- Automatic retry on token expiration

### ⏳ Models (To Be Created)
- StorageItem, Category, Location, Author, PositionSchema, Content

### ⏳ Services (To Be Created)
- ItemService, CategoryService, LocationService, AuthorService, PreviewService

### ⏳ View Models (To Be Created)
- Protocol-based architecture with @Observable
- Implementations for all CRUD operations

### ⏳ Views (To Be Created)
- SwiftUI views for all entities
- QR code generation/scanning
- Form sheets and pickers

## Usage

### Configuration

Add to your app's `Info.plist`:

```xml
<key>API_BASE_URL</key>
<string>http://localhost:3000</string>

<key>AUTH_ISSUER</key>
<string>https://auth.rxlab.app</string>

<key>AUTH_CLIENT_ID</key>
<string>your-client-id</string>

<key>AUTH_REDIRECT_URI</key>
<string>rxstorage://oauth-callback</string>

<key>AUTH_SCOPES</key>
<string>openid email profile offline_access</string>
```

### Authentication

```swift
import RxStorageCore

// Authenticate user
let oauthManager = OAuthManager.shared
try await oauthManager.authenticate()

// Check authentication status
if oauthManager.isAuthenticated {
    print("User: \(oauthManager.currentUser?.name ?? "Unknown")")
}

// Logout
await oauthManager.logout()
```

### API Requests

```swift
import RxStorageCore

// Fetch items
let items: [StorageItem] = try await APIClient.shared.get(
    .listItems(filters: nil),
    responseType: [StorageItem].self
)

// Create item
let newItem = NewItemRequest(title: "My Item", ...)
let createdItem: StorageItem = try await APIClient.shared.post(
    .createItem,
    body: newItem,
    responseType: StorageItem.self
)

// Update item
let updatedItem: StorageItem = try await APIClient.shared.put(
    .updateItem(id: 1),
    body: updateData,
    responseType: StorageItem.self
)

// Delete item
try await APIClient.shared.delete(.deleteItem(id: 1))
```

## Testing

Run tests in Xcode:
```
cmd + U
```

Or via command line:
```bash
swift test
```

## Architecture

### Protocol-Oriented MVVM
- View Models conform to protocols for testability
- @Observable macro for reactive state management
- Dependency injection for easy mocking

### No External Dependencies
- Uses only Apple frameworks (Foundation, SwiftUI, AuthenticationServices)
- No third-party packages required

### API-Only Persistence
- No local database (SwiftData/CoreData)
- API as the single source of truth
- In-memory caching only (NSCache for images)

## Development Status

- ✅ Phase 0: Web API Bearer token support (Complete)
- 🚧 Phase 1: Foundation layer (60% - Config, Auth, Networking complete)
- ⏳ Phase 2: Models & Services (Not started)
- ⏳ Phase 3: View Models (Not started)
- ⏳ Phase 4: Views (Not started)
- ⏳ Phase 5: Testing (Not started)

## License

Private - RxLab Internal Use Only
