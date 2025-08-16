// Features/Settings/CalendarPickerView.swift
import SwiftUI
import EventKit

struct CalendarPickerView: View {
    @StateObject private var calendarSync = CalendarSyncService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if calendarSync.authorizationStatus != .fullAccess {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 48))
                                .foregroundColor(.orange)
                            
                            Text("Calendar Access Required")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            
                            Text("To sync tasks with your calendar, please grant calendar access in Settings.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Request Access") {
                                Task {
                                    await calendarSync.requestCalendarAccess()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    Section {
                        ForEach(calendarSync.getAvailableCalendars(), id: \.calendarIdentifier) { calendar in
                            CalendarRow(
                                calendar: calendar,
                                isSelected: calendar.calendarIdentifier == calendarSync.selectedCalendar?.calendarIdentifier
                            ) {
                                calendarSync.setSelectedCalendar(calendar)
                                dismiss()
                            }
                        }
                    } header: {
                        Text("Select Calendar")
                    } footer: {
                        Text("Choose which calendar to sync your tasks to. Only calendars that allow modifications are shown.")
                    }
                }
                
                if !calendarSync.syncErrors.isEmpty {
                    Section("Recent Errors") {
                        ForEach(calendarSync.syncErrors, id: \.self) { error in
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        Button("Clear Errors") {
                            calendarSync.clearErrors()
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Calendar Selection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct CalendarRow: View {
    let calendar: EKCalendar
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Circle()
                    .fill(Color(calendar.cgColor))
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(calendar.title)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    if let source = calendar.source {
                        Text(source.title)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.body.weight(.semibold))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview {
    CalendarPickerView()
}
#endif
