# Calendar Sync Integration Guide

## Overview

The new Calendar Sync Engine implements the production-ready specification you provided. It features:

- ✅ **Dedicated "Kuna" Calendar**: Automatically created and managed
- ✅ **Two-Way Sync**: Tasks ↔ Calendar Events with conflict resolution
- ✅ **Incremental Sync**: Using server and local change cursors
- ✅ **Signature-Based Conflict Avoidance**: Prevents ping-pong updates
- ✅ **Background Refresh**: Debounced event store change detection
- ✅ **Production Architecture**: Modular, testable, and maintainable

## Quick Integration

### 1. Set Up the API Connection

In your app initialization (e.g., `AppState` or main view):

```swift
// Set up the calendar sync API connection
CalendarSyncService.shared.setAPI(yourVikunjaAPIInstance)
```

### 2. Enable Advanced Sync

Users can now access the advanced sync through:
**Settings → Calendar Integration → Advanced Sync**

### 3. Configure Enabled Lists

The sync engine needs to know which projects/lists to sync:

```swift
// Example: Enable sync for specific project IDs
let projectIds = ["1", "2", "3"] // Your project IDs as strings
CalendarSyncService.shared.setEnabledLists(projectIds)
```

## Architecture

### Core Components

```
CalendarSyncEngine (Main orchestrator)
├── CalendarManager (EventKit operations)
├── TaskEventMapper (Data transformation)
├── SyncStatePersistence (State management)
├── EventSignature (Conflict prevention)
└── Debouncer (Performance optimization)
```

### Data Flow

1. **Pull Sync**: Server → Calendar
   - Fetch tasks with `updatedSince` cursor
   - Transform to calendar events
   - Apply signatures to prevent loops

2. **Push Sync**: Calendar → Server  
   - Detect changed events since last scan
   - Extract edits (title, dates, reminders)
   - Patch tasks via API
   - Update signatures

### Sync Windows

- **Pull Window**: 8 weeks back, 12 months forward
- **Push Window**: 6 months back and forward
- **Configurable**: Modify `SyncConst` values as needed

## API Integration

### Required Methods

Your `VikunjaAPI` already implements the required protocol:

```swift
protocol CalendarSyncAPI {
    func fetchTasks(updatedSince: String?, listIDs: [String], window: DateInterval) async throws -> [CalendarSyncTask]
    func patchTask(_ patch: TaskPatch) async throws -> CalendarSyncTask
}
```

### Task Mapping

The system automatically converts between `VikunjaTask` and `CalendarSyncTask`:

| VikunjaTask Property | CalendarSyncTask Property | Notes |
|---------------------|---------------------------|-------|
| `id` | `id` | Converted to String |
| `title` | `title` | Direct mapping |
| `description` | `notes` | Direct mapping |
| `dueDate` | `dueDate` | Direct mapping |
| `reminders` | `reminders` | Converted to relative |
| `done` | `deleted` | Completed = deleted for calendar |

## Configuration

### Sync Constants

Modify `SyncConst` in `SyncConstants.swift`:

```swift
enum SyncConst {
    static let calendarTitle = "Kuna"
    static let syncWindowBack: TimeInterval = 60*60*24*56   // 8 weeks
    static let syncWindowForward: TimeInterval = 60*60*24*365 // 12 months
    // ... other constants
}
```

### User Settings

The engine respects these user preferences:
- **Enable/Disable Sync**: Master toggle
- **Two-Way Sync**: Allow calendar → task updates
- **Enabled Lists**: Which projects to sync

## Testing

### Manual Testing

1. **Enable Advanced Sync** in Settings
2. **Grant Calendar Permission** when prompted
3. **Create/Edit Tasks** with due dates
4. **Check Calendar App** for "Kuna" calendar
5. **Edit Events** in Calendar (if two-way enabled)
6. **Verify Changes** sync back to tasks

### Automated Testing

The architecture supports unit testing:

```swift
// Example test setup
let mockAPI = MockCalendarSyncAPI()
let engine = CalendarSyncEngine()
engine.setAPI(mockAPI)
```

## Troubleshooting

### Common Issues

1. **No Calendar Permission**: Check Settings → Privacy → Calendars
2. **Tasks Not Syncing**: Verify enabled lists are configured
3. **Duplicate Events**: Check signature implementation
4. **Sync Conflicts**: Review two-way sync settings

### Debug Information

The engine provides detailed logging:
- `Pull sync completed for window: ...`
- `Push sync completed, processed X changes`
- `Processed patch for task X`

### Error Handling

Errors are collected in `syncEngine.syncErrors`:
- API connection issues
- Calendar permission problems
- Event creation failures
- Conflict resolution errors

## Migration from Legacy Sync

The new engine coexists with the legacy sync system:

1. **Legacy Methods**: Still available for backward compatibility
2. **New Methods**: Use `enableNewSync()`, `performFullSync()`, etc.
3. **Gradual Migration**: Switch users to advanced sync over time

## Performance Considerations

### Optimizations

- **Incremental Sync**: Only processes changed data
- **Debounced Updates**: Prevents excessive sync operations
- **Windowed Queries**: Limits data scope for performance
- **Signature Caching**: Avoids unnecessary event updates

### Background Sync

The engine automatically syncs when:
- **App Launch**: Initial sync
- **Calendar Changes**: Debounced event store notifications
- **Manual Trigger**: User-initiated sync

## Security & Privacy

### Data Handling

- **Local Storage**: Sync state in UserDefaults
- **No External Servers**: Direct Calendar ↔ Vikunja sync
- **User Control**: Granular sync preferences

### Permissions

- **Calendar Access**: Required for EventKit operations
- **Clear Messaging**: Users understand why access is needed

## Future Enhancements

The architecture supports:
- **Multiple Calendar Support**: Sync to different calendars
- **Custom Event Templates**: User-defined event formats
- **Advanced Conflict Resolution**: User-guided resolution
- **Background App Refresh**: System-scheduled sync
- **Push Notifications**: Server-triggered sync

## Support

For issues or questions:
1. Check the error logs in Advanced Sync view
2. Verify API integration is correct
3. Test with simple tasks first
4. Review the sync windows and settings
