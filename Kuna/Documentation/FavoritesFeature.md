# Task Favorites Feature

This document explains the task favorites functionality in Kuna.

## Overview

The favorites feature allows users to mark important tasks as favorites for quick access. Favorite tasks are displayed in a dedicated section in the sidebar navigation and can be managed throughout the app.

## Features

### 1. Mark Tasks as Favorites
- **Task Detail View**: Star button in the toolbar
- **Task List**: Swipe left to reveal favorite action
- **Visual Feedback**: Yellow star icon when favorited

### 2. Favorites View
- **Dedicated View**: Accessible from sidebar navigation
- **Quick Access**: All favorite tasks in one place
- **Sorting**: Tasks sorted by completion status, then alphabetically
- **Pull to Refresh**: Update favorites list
- **Empty State**: Helpful guidance when no favorites exist

### 3. Navigation Integration
- **Sidebar Menu**: Favorites section with star icon
- **Color Coding**: Yellow star for visual consistency
- **Quick Access**: One tap to view all favorites

## User Interface

### Favorites in Sidebar
- **Icon**: Yellow star (`star.fill`)
- **Position**: First item in navigation menu
- **Quick Access**: Direct navigation to favorites view

### Task Detail Integration
- **Toolbar Button**: Star icon next to Edit button
- **State Indication**: Filled star (favorited) vs outline star (not favorited)
- **Real-time Updates**: Immediate visual feedback

### Task List Integration
- **Swipe Actions**: Left swipe reveals favorite toggle
- **Visual Indicator**: Yellow star action button
- **Batch Operations**: Can favorite/unfavorite multiple tasks

### Favorites View Features
- **Header**: Shows count of favorite tasks
- **Task Rows**: Same design as regular task lists
- **Completion Toggle**: Can mark tasks complete/incomplete
- **Task Details**: Tap to open full task detail view
- **Refresh**: Pull-to-refresh functionality

## API Integration

### Endpoints Used
```
GET /tasks/all?is_favorite=true  - Fetch favorite tasks
POST /tasks/{id}/favorite        - Toggle favorite status
```

### Data Model
```swift
struct VikunjaTask {
    // ... existing fields
    var isFavorite: Bool  // Favorite status
}
```

## Technical Implementation

### Core Components
1. **FavoritesView**: Main favorites display
2. **FavoritesViewWithMenu**: Navigation wrapper
3. **Enhanced TaskDetailView**: Favorite button in toolbar
4. **Enhanced TaskListView**: Swipe actions for favorites
5. **Updated SideMenuView**: Favorites navigation item

### State Management
- **Local State**: Immediate UI updates
- **API Sync**: Background synchronization
- **Error Handling**: Graceful failure recovery
- **Cache Updates**: Widget and shared file updates

### Navigation Flow
```
Sidebar → Favorites → Task Detail → Edit/Favorite
   ↓         ↓           ↓
Menu     Task List   Full Details
```

## User Experience

### Favoriting Workflow
1. **From Task List**: Swipe left → Tap star
2. **From Task Detail**: Tap star in toolbar
3. **Visual Feedback**: Star fills with yellow color
4. **Immediate Update**: Task appears in favorites

### Unfavoriting Workflow
1. **From Favorites**: Swipe left → Tap star slash
2. **From Task Detail**: Tap filled star in toolbar
3. **Visual Feedback**: Star becomes outline
4. **List Update**: Task removed from favorites view

### Empty State
- **Helpful Guidance**: Explains how to add favorites
- **Visual Design**: Star slash icon with instructions
- **Feature Discovery**: Teaches users about favoriting

## Benefits

1. **Quick Access**: Important tasks always available
2. **Organization**: Separate high-priority items
3. **Productivity**: Faster task management
4. **Visual Clarity**: Clear favorite indicators
5. **Sync**: Favorites work across all devices
6. **Integration**: Seamless with existing workflows

## Future Enhancements

Potential improvements:
- **Smart Favorites**: Auto-suggest important tasks
- **Favorite Categories**: Organize favorites by type
- **Favorite Shortcuts**: Quick actions for favorites
- **Favorite Widgets**: Home screen favorite tasks
- **Favorite Notifications**: Alerts for favorite task updates
