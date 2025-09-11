// Features/Settings/DisableCalendarSyncView.swift
import SwiftUI

struct DisableCalendarSyncView: View {
    let engine: CalendarSyncEngine
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDisposition: DisableDisposition = .keepEverything
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                headerSection
                
                optionsSection
                
                Spacer()
                
                actionButtons
            }
            .padding()
            .navigationTitle(String(localized: "settings.calendarSync.disable.button"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    
                    Button(String(localized: "common.cancel", comment: "Cancel button")) { dismiss() }
                }
            }
            .alert(String(localized: "common.error"), isPresented: .constant(errorMessage != nil)) {
                
                Button(String(localized: "common.ok", comment: "OK button")) { errorMessage = nil }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.minus")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                
                Text(String(localized: "settings.calendarSync.disable.title", comment: "Title for disable calendar sync"))
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(String(localized: "settings.calendarSync.disable.subtitle", comment: "Subtitle for disable calendar sync"))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var optionsSection: some View {
        VStack(spacing: 12) {
            ForEach(DisableDisposition.allCases, id: \.self) { disposition in
                DispositionOptionCard(
                    disposition: disposition,
                    isSelected: selectedDisposition == disposition,
                    action: { selectedDisposition = disposition }
                )
            }
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            
            Button(String(localized: "settings.calendarSync.disable.button", comment: "Disable calendar sync button")) {
                disableSync()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .disabled(isProcessing)
            
            if isProcessing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text(String(localized: "settings.processing.title", comment: "Title for processing"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func disableSync() {
        Task {
            await MainActor.run {
                isProcessing = true
                errorMessage = nil
            }
            
            do {
                // Disable sync with selected disposition
                try await engine.disableSync(disposition: selectedDisposition)
                
                // Update app settings
                await MainActor.run {
                    appSettings.calendarSyncPrefs = CalendarSyncPrefs()
                    appSettings.calendarSyncEnabled = false
                    isProcessing = false
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct DispositionOptionCard: View {
    let disposition: DisableDisposition
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(disposition.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Text(disposition.detailDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    if disposition == .removeKunaEvents {
                        
                        Text(String(localized: "settings.calendarSync.disable.disposition.removeKunaEvents.title",
                                    comment: "Title for this will permanently delete all synced events"))
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    if disposition == .deleteEverything {
                        
                        Text(String(localized: "settings.calendarSync.disable.disposition.deleteEverything.title",
                                    comment: "Title for this will permanently delete all kuna calendars and events"))
                            .font(.caption)
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview {
    DisableCalendarSyncView(engine: CalendarSyncEngine())
        .environmentObject(AppSettings.shared)
}
#endif
