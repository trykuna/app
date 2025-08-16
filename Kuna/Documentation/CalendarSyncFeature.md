# Calendar Sync Feature

## Overview

The Calendar Sync feature allows users to synchronize their Vikunja tasks with their device's calendar app. This provides a seamless integration between task management and calendar scheduling.

## Features

### Core Functionality
- **One-way sync**: Tasks → Calendar events
- **Bidirectional sync**: Calendar changes → Task updates (optional)
- **Per-task control**: Users can choose which tasks to sync
- **Automatic sync**: New tasks can be automatically synced based on user preferences

### Task-to-Event Mapping
- **Task Title** → **Event Title**
- **Task Description** → **Event Notes**
- **Task Start Date** → **Event Start Time**
- **Task Due Date** → **Event End Time** (if no end date specified)
- **Task End Date** → **Event End Time**
- **Task Reminders** → **Event Alarms**
- **Task Priority** → **Event Priority** (High/Medium/Low)

### Smart Date Handling
- If only start date is provided: Creates 1-hour event
- If only due date is provided: Creates 1-hour event ending at due time
- If only end date is provided: Creates 1-hour event ending at specified time
- If multiple dates are provided: Uses start and end dates appropriately

## User Interface

### Settings Integration
- **Calendar Sync Toggle**: Enable/disable calendar sync
- **Calendar Selection**: Choose which calendar to sync to
- **Auto-sync New Tasks**: Automatically sync newly created tasks
- **Sync Tasks with Dates Only**: Only sync tasks that have date information
- **Sync Status View**: View sync status, conflicts, and errors

### Task Detail View
- **Calendar Sync Section**: Shows sync status for individual tasks
- **Sync Toggle**: Manually sync/unsync individual tasks
- **Sync Status Indicator**: Shows if task is synced to calendar

### Task List View
- **Sync Indicator**: Small badge showing which tasks are synced to calendar

## Technical Implementation

### Services
- **CalendarSyncService**: Core EventKit integration and calendar operations
- **CalendarSyncManager**: Orchestrates sync operations and conflict resolution
- **AppSettings**: Stores user preferences for calendar sync

### Key Components
- **CalendarPickerView**: UI for selecting which calendar to sync to
- **CalendarSyncStatusView**: Detailed sync status and conflict resolution
- **Task Event Mapping**: Logic for converting between tasks and calendar events

### Permissions
- Requires calendar access permission (EventKit)
- Graceful handling of permission denial
- Clear user messaging about permission requirements

## Usage Instructions

### Initial Setup
1. Go to Settings → Calendar Integration
2. Enable "Calendar Sync"
3. Grant calendar access when prompted
4. Select which calendar to sync to
5. Configure sync preferences

### Syncing Tasks
1. **Automatic**: New tasks with dates are automatically synced (if enabled)
2. **Manual**: Use the sync button in Task Detail view
3. **Bulk**: Use "Sync Now" in Calendar Sync Status view

### Managing Conflicts
1. View conflicts in Calendar Sync Status
2. Choose resolution strategy:
   - Use Task data
   - Use Calendar data
   - Manual resolution

## Error Handling

### Common Issues
- **No Calendar Access**: Clear messaging and permission request
- **No Calendar Selected**: Prompt to select calendar in settings
- **Sync Failures**: Detailed error messages with suggested actions
- **Conflicts**: User-friendly conflict resolution interface

### Error Recovery
- Automatic retry for transient failures
- Clear error messages with actionable steps
- Ability to clear error history

## Privacy and Security

### Data Handling
- Task data is only stored in user's personal calendar
- No data is sent to external servers beyond Vikunja API
- Calendar events include task ID for identification

### Permissions
- Only requests necessary calendar permissions
- Respects user's calendar access choices
- Clear explanation of why permissions are needed

## Future Enhancements

### Potential Features
- Multiple calendar support
- Custom event templates
- Advanced conflict resolution
- Sync scheduling (hourly, daily, etc.)
- Calendar-to-task creation (reverse sync)
- Integration with calendar widgets

### Technical Improvements
- Background sync capabilities
- Sync performance optimization
- Enhanced conflict detection
- Bulk operations support

## Testing Scenarios

### Basic Functionality
- [ ] Enable calendar sync
- [ ] Select calendar
- [ ] Sync task with all date fields
- [ ] Sync task with only due date
- [ ] Sync task with only start date
- [ ] Remove task from calendar
- [ ] Update synced task

### Edge Cases
- [ ] Task with no dates (when "dates only" is disabled)
- [ ] Task with invalid dates
- [ ] Calendar permission denied
- [ ] No writable calendars available
- [ ] Calendar deleted after selection
- [ ] Network connectivity issues

### Conflict Resolution
- [ ] Task updated in app, event updated in calendar
- [ ] Event deleted in calendar, task still exists
- [ ] Task deleted in app, event still exists
- [ ] Multiple conflicting changes

### Performance
- [ ] Sync large number of tasks
- [ ] Sync with slow network connection
- [ ] Background sync behavior
- [ ] Memory usage during sync

## Known Limitations

- Requires iOS 14.0+ for full EventKit functionality
- Limited to calendars that allow content modifications
- Sync conflicts require manual resolution
- No support for recurring task patterns (yet)
- Calendar events are identified by custom URL scheme

## Support and Troubleshooting

### Common Solutions
1. **Sync not working**: Check calendar permissions and selection
2. **Events not appearing**: Verify calendar is visible in Calendar app
3. **Conflicts appearing**: Review recent changes in both apps
4. **Performance issues**: Reduce sync frequency or task count

### Debug Information
- Sync status and last sync time
- Error logs with timestamps
- Calendar permissions status
- Selected calendar information
