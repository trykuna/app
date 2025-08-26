// Features/Settings/CalendarPickerView.swift
import SwiftUI
import EventKit

struct CalendarPickerView: View {
    @StateObject private var calendarSync = CalendarSyncService.shared
    @Environment(\.dismiss) private var dismiss

    // SwiftUI-native alert state (replaces UIKit alert-in-row)
    @State private var pendingCalendarSelection: EKCalendar?
    @State private var showSwitchAlert = false
    @State private var showAdvancedOptions = false

    // Precompute to keep the ForEach closure simple
    private var calendars: [EKCalendar] {
        calendarSync.getAvailableCalendars()
    }

    var body: some View {
        NavigationView {
            List {
                listContent()
            }
            // .navigationTitle("Calendar Selection")
            .navigationTitle(String(localized: "settings.calendarSync.selection.title", comment: "Calendar selection navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Button("Done") { dismiss() }
                    Button(String(localized: "common.done", comment: "Done button")) { dismiss() }
                }
            }
            .modifier(CalendarAlertModifier(
                showSwitchAlert: $showSwitchAlert,
                pendingCalendarSelection: $pendingCalendarSelection,
                calendarSync: calendarSync,
                dismiss: dismiss
            ))
        }
    }

    // Pull the list content out so the type checker has less to chew on.
    @ViewBuilder
    private func listContent() -> some View {
        if calendarSync.authorizationStatus != .fullAccess {
            accessRequiredSection
        } else {
            defaultCalendarSection
            
            if showAdvancedOptions {
                selectionSection
            }
        }

        if !calendarSync.syncErrors.isEmpty {
            errorsSection
        }
    }

    // MARK: - Sections
    
    @ViewBuilder
    private var defaultCalendarSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                // Default Calendar Info
                HStack {
                    Circle()
                        .fill(Color.indigo)
                        .frame(width: 14, height: 14)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        // Text("Kuna Tasks")
                        Text(String(localized: "settings.calendarSync.default.title", comment: "Title for default calendar"))
                            .font(.body)
                            .fontWeight(.medium)
                        // Text("Default calendar for all tasks")
                        Text(String(localized: "settings.calendarSync.default.subtitle", comment: "Subtitle for default calendar"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if calendarSync.selectedCalendar?.title == "Kuna Tasks" {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                            .font(.body.weight(.semibold))
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if let defaultCalendar = calendarSync.getOrCreateDefaultCalendar() {
                        calendarSync.setSelectedCalendar(defaultCalendar)
                        dismiss()
                    }
                }
                
                Divider()
                
                // Advanced Options Toggle
                Button(action: { showAdvancedOptions.toggle() }) {
                    HStack {
                        Image(systemName: showAdvancedOptions ? "chevron.down" : "chevron.right")
                            .foregroundColor(.blue)
                            .font(.caption)
                            .frame(width: 20)
                        
                        // Text("Advanced Options")
                        Text(String(localized: "settings.calendarSync.advanced.title", comment: "Title for advanced options"))
                            .font(.body)
                            .foregroundColor(.blue)
                        
                        Spacer()
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            // Text("Calendar Selection")
            // Already commented
            Text(String(localized: "settings.calendarSync.selection.title", comment: "Title for calendar selection"))
        } footer: {
            // Text("Kuna will automatically create and use a dedicated 'Kuna Tasks' calendar. Tap Advanced Options to choose a different calendar.")
            Text(String(localized: "settings.calendarSync.selection.subtitle", comment: "Subtitle for calendar selection"))
        }
    }

    @ViewBuilder
    private var accessRequiredSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)

                // Text("Calendar Access Required")
                Text(String(localized: "settings.calendarSync.access.title", comment: "Title for calendar access required"))
                    .font(.headline)
                    .multilineTextAlignment(.center)

                // Text("To sync tasks with your calendar, please grant calendar access in Settings.")
                Text(String(localized: "settings.calendarSync.access.subtitle", comment: "Subtitle for calendar access required"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                // Button("Request Access") {
                Button(String(localized: "settings.calendarSync.requestAccess", comment: "Request access button")) {
                    Task { await calendarSync.requestCalendarAccess() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var selectionSection: some View {
        Section {
            ForEach(calendars, id: \.calendarIdentifier) { calendar in
                CalendarRow(
                    calendar: calendar,
                    isSelected: calendar.calendarIdentifier == calendarSync.selectedCalendar?.calendarIdentifier
                ) {
                    handleCalendarTap(calendar)
                }
            }
        } header: {
            // Text("Choose Different Calendar")
            Text(String(localized: "settings.calendarSync.selection.advanced.title", comment: "Title for choose different calendar"))
        } footer: {
            // Text("Select any of your existing calendars to sync tasks to. Only calendars that allow modifications are shown.")
            Text(String(localized: "settings.calendarSync.selection.advanced.subtitle", comment: "Subtitle for choose different calendar"))
        }
    }

    @ViewBuilder
    private var errorsSection: some View {
        Section {
            ForEach(0..<calendarSync.syncErrors.count, id: \.self) { index in
                Text(calendarSync.syncErrors[index])
                    .font(.caption)
                    .foregroundColor(.red)
            }
            // Button("Clear Errors") {
            Button(String(localized: "settings.calendarSync.clearErrors", comment: "Clear calendar sync errors button")) {
                calendarSync.syncErrors.removeAll()
            }
        } header: {
            // Text("Recent Errors")
            Text(String(localized: "settings.calendarSync.errors.title", comment: "Title for recent errors"))
        }
    }

    // MARK: - Actions

    @MainActor
    private func handleCalendarTap(_ newCalendar: EKCalendar) {
        if let current = calendarSync.selectedCalendar,
           current.calendarIdentifier != newCalendar.calendarIdentifier {
            pendingCalendarSelection = newCalendar
            showSwitchAlert = true
        } else {
            calendarSync.setSelectedCalendar(newCalendar)
            dismiss()
        }
    }
}

// MARK: - Alert Modifier

struct CalendarAlertModifier: ViewModifier {
    @Binding var showSwitchAlert: Bool
    @Binding var pendingCalendarSelection: EKCalendar?
    let calendarSync: CalendarSyncService
    let dismiss: DismissAction
    
    func body(content: Content) -> some View {
        content
            // .alert("Switch Calendar?",
            .alert(String(localized: "settings.calendarSync.switchCalendar.title", comment: "Switch calendar alert title"),
                   isPresented: $showSwitchAlert,
                   presenting: pendingCalendarSelection) { newCalendar in
                // Button("Switch") {
                Button(String(localized: "settings.calendarSync.switch", comment: "Switch button")) {
                    // Switch to new calendar (existing events will remain in old calendar)
                    calendarSync.setSelectedCalendar(newCalendar)
                    dismiss()
                }
                Button(String(localized: "common.cancel", comment: "Cancel button"), role: .cancel) {
                    pendingCalendarSelection = nil
                }
            } message: { newCalendar in
                Text("calendar.sync.switch \(newCalendar.title)",
                     comment: "Confirmation prompt when switching to a new calendar for sync. Placeholder is the new calendar’s title")

            }
    }
}

// MARK: - Row

struct CalendarRow: View {
    let calendar: EKCalendar
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Circle()
                    .fill(Color(cgColor: calendar.cgColor)) // non-optional CGColor init
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(calendar.title)
                        .font(.body)
                        .foregroundColor(.primary)

                    // EKCalendar.source is non-optional
                    Text(calendar.source.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
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
