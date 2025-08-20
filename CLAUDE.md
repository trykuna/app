# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kuna is an iOS task management app that serves as a client for the Vikunja API. Built with SwiftUI for iOS 18.4+, it features task management, calendar integration, and background sync capabilities.

## Build and Development Commands

```bash
# Open in Xcode
open Kuna.xcodeproj

# Build from command line
xcodebuild -project Kuna.xcodeproj -scheme Kuna build

# Clean build
xcodebuild -project Kuna.xcodeproj -scheme Kuna clean

# Run on simulator
xcodebuild -project Kuna.xcodeproj -scheme Kuna -destination 'platform=iOS Simulator,name=iPhone 16 Pro' run
```

## Architecture

### Core Components

1. **AppState** (`App/AppState.swift`): Central authentication and global state management using `@ObservableObject`
2. **VikunjaAPI** (`Services/VikunjaAPI.swift`): Core API client with retry logic, handles all Vikunja server communication
3. **CalendarSyncEngine** (`Services/CalendarSyncEngine.swift`): Bidirectional calendar synchronization with EventKit
4. **AppSettings** (`Services/AppSettings.swift`): Persistent settings using UserDefaults with `@Published` properties

### Navigation Flow

`KunaApp` → `RootView` → `MainContainerView` → Feature Views

The app uses a custom side menu navigation pattern with gesture support, not standard NavigationStack.

### Authentication Modes

```swift
enum AuthenticationMethod {
    case usernamePassword    // Full access including user management
    case personalToken      // Limited access, read-only user features
}
```

Personal token authentication has restricted features - user management is read-only, cannot update user assignments.

### Background Tasks

Background sync uses registered identifiers:
- `tech.systemsmystery.kuna.bg.refresh` 
- `tech.systemsmystery.kuna.bg.processing`

Debug intervals: 30s, 1m for testing. Production: 15m to 24h.

### Feature Organization

Each feature lives in `Features/[FeatureName]/` with its own views and logic:
- Auth: Login, TOTP authentication
- Tasks: Core task CRUD operations
- Projects: Project management views
- Labels: Label creation and management
- Calendar: Calendar sync settings
- Settings: App preferences and customization

### Data Models

Primary models in `Models/`:
- `VikunjaTask`: Comprehensive task with 20+ properties
- `VikunjaUser`: User with display names and avatars
- `Project`: Project organization structure
- `Label`: Color-coded categorization
- `TaskFilter`: Advanced filtering system

### Service Layer Patterns

Services use `@MainActor` for thread safety and follow singleton pattern where appropriate. Key services:
- API calls through `VikunjaAPI`
- Background sync via `BackgroundSyncService`
- Calendar operations through `CalendarSyncEngine`
- Analytics via `Analytics` service (TelemetryDeck)

### Testing Approach

Currently no dedicated test targets. Components include preview providers for SwiftUI development. `AppIconTestView.swift` exists for icon testing.

## Key Implementation Notes

### Calendar Sync
- Uses event signatures for change detection
- Debounced sync operations to prevent excessive API calls
- Persists sync state in UserDefaults

### App Icons
- 9 alternate icons configured in Info.plist
- Runtime switching via `UIApplication.shared.setAlternateIconName`
- Icons: Gold, Orange, Red, Yellow, Neon, Silver, Pride, AltPride, TransPride

### Error Handling
- API errors are wrapped in `VikunjaError` enum
- Network retry logic with exponential backoff
- User-facing error messages through alerts

### State Management
- Global state in `AppState` using `@StateObject`
- Feature-specific state in view models
- Settings persisted via `AppSettings` service

## Important Constraints

1. iOS 18.4+ minimum deployment target
2. SwiftUI-only, no UIKit views except where required by system APIs
3. EventKit for calendar integration requires permission prompts
4. Background processing has iOS system limitations on frequency