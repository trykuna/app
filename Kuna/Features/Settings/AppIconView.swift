// Features/Settings/AppIconView.swift
import SwiftUI

struct AppIconView: View {
    @StateObject private var iconManager = AppIconManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        AdaptiveLogo(iconManager.currentIcon.logoVariant)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        
                        VStack(spacing: 4) {
                            // Text("Current Icon")
                            Text(String(localized: "settings.appIcon.current.title", comment: "Title for current app icon"))
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text(iconManager.currentIcon.displayName)
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Icon Grid
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(AppIcon.allCases) { icon in
                            AppIconCard(
                                icon: icon,
                                isSelected: icon == iconManager.currentIcon,
                                isChanging: iconManager.isChangingIcon
                            ) {
                                selectIcon(icon)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Info section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            // Text("About App Icons")
                            Text(String(localized: "settings.appIcon.info.title", comment: "Title for app icon info"))
                                .font(.headline)
                        }
                        
                        // Text("Choose from a variety of app icons to personalize your Kuna experience. The icon change will take effect immediately and persist across app launches.")
                        Text(String(localized: "settings.appIcon.info.text", comment: "Text for app icon info"))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 20)
                }
            }
            // .navigationTitle("App Icon")
            .navigationTitle(String(localized: "settings.appIcon.title", comment: "App icon settings title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Button("Done") {
                    Button(String(localized: "common.done", comment: "Done button")) {
                        dismiss()
                    }
                }
            }
            .alert(String(localized: "common.error"), isPresented: $showingError) {
                // Button("OK") { }
                Button(String(localized: "common.ok", comment: "OK button")) { }
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if iconManager.isChangingIcon {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        // Text("Changing Icon...")
                        Text(String(localized: "settings.appIcon.changing", comment: "Label shown when changing app icon"))
                            .font(.headline)
                    }
                    .padding(24)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 8)
                }
            }
        }
    }
    
    private func selectIcon(_ icon: AppIcon) {
        guard !iconManager.isChangingIcon else { return }
        
        Task {
            do {
                try await iconManager.setIcon(icon)
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

struct AppIconCard: View {
    let icon: AppIcon
    let isSelected: Bool
    let isChanging: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    // Icon image
                    AdaptiveLogo(icon.logoVariant)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    
                    // Selection indicator
                    if isSelected {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.accentColor, lineWidth: 3)
                            .frame(width: 60, height: 60)
                        
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                                    .background(Color(.systemBackground))
                                    .clipShape(Circle())
                                    .font(.system(size: 16, weight: .semibold))
                                    .offset(x: 8, y: 8)
                            }
                        }
                        .frame(width: 60, height: 60)
                    }
                }
                
                VStack(spacing: 2) {
                    Text(icon.displayName)
                        .font(.caption)
                        .fontWeight(isSelected ? .semibold : .medium)
                        .foregroundColor(isSelected ? .accentColor : .primary)
                    
                    Text(icon.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isChanging)
        .opacity(isChanging ? 0.6 : 1.0)
    }
}

#Preview {
    AppIconView()
}
