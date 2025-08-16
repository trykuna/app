# User Management & Task Assignment

This document explains the user management and task assignment features in Kuna.

## Overview

Kuna supports user lookup and task assignment functionality, but **only when authenticated with username and password**. This feature is not available when using personal API tokens.

## Authentication Requirements

### ✅ Username & Password Login
- **User search**: ✅ Available
- **Task assignment**: ✅ Available
- **View assignees**: ✅ Available
- **Remove assignees**: ✅ Available

### ❌ Personal API Token Login
- **User search**: ❌ Not available
- **Task assignment**: ❌ Not available
- **View assignees**: ✅ Available (read-only)
- **Remove assignees**: ❌ Not available

## Features

### 1. User Search
- Search for users by username or display name
- Real-time search results
- User avatars with initials
- Display username, name, and email

### 2. Task Assignment
- Assign multiple users to a task
- Remove users from task assignments
- Visual indicators in task lists
- Assignment management in task details

### 3. Visual Indicators
- **Task List**: Shows assignee count badge
- **Task Detail**: Dedicated assignees section
- **Settings**: Shows user management availability status

## User Interface

### Task Detail View
The task detail view includes an "ASSIGNEES" section that shows:
- Current assignees with avatars
- Add/remove buttons (when available)
- Task creator information
- Read-only mode for token users

### User Search View
- Search bar with real-time filtering
- User list with avatars and details
- Tap to assign functionality
- Empty states and error handling

### Settings View
- User management status indicator
- Shows whether feature is available
- Explains authentication requirements

## API Endpoints

The following Vikunja API endpoints are used:

### User Search
```
GET /users?s={query}
```

### Task Assignment
```
PUT /tasks/{taskId}/assignees
Body: { "user_id": userId }
```

### Remove Assignment
```
DELETE /tasks/{taskId}/assignees/{userId}
```

### Get Assignees
```
GET /tasks/{taskId}/assignees
```

## Data Models

### VikunjaUser
```swift
struct VikunjaUser: Identifiable, Codable {
    let id: Int
    let username: String
    let name: String?
    let email: String?
    // ... other fields
}
```

### Enhanced VikunjaTask
```swift
struct VikunjaTask {
    // ... existing fields
    var assignees: [VikunjaUser]?
    var createdBy: VikunjaUser?
}
```

## Usage Examples

### Check if user management is available
```swift
if appState.canManageUsers {
    // Show assignment UI
} else {
    // Show read-only view
}
```

### Search for users
```swift
let users = try await api.searchUsers(query: "john")
```

### Assign user to task
```swift
let updatedTask = try await api.assignUserToTask(taskId: task.id, userId: user.id)
```

## Error Handling

- **Network errors**: Displayed to user with retry options
- **Permission errors**: Graceful fallback to read-only mode
- **Search errors**: Clear error messages with suggestions
- **Assignment errors**: Rollback with error notification

## Security Considerations

- User search requires proper authentication
- Assignment operations validate permissions
- Personal tokens cannot modify assignments
- All user data is handled securely

## Future Enhancements

Potential future improvements:
- User avatars from Gravatar/custom sources
- Bulk assignment operations
- Assignment notifications
- User role management
- Team-based assignments
