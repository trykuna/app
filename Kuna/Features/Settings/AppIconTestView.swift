// Features/Settings/AppIconTestView.swift
import SwiftUI

// This view is for testing the app icon functionality
// You can use this to test icon switching without having all the actual icon files
struct AppIconTestView: View {
    @StateObject private var iconManager = AppIconManager.shared
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                Text(String(localized: "settings.appIcon.test.title", comment: "App icon test view title"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("settings.icon.current \(iconManager.currentIcon.displayName)",
                     comment: "Label showing the current app icon name")

                    .font(.headline)
                
                if iconManager.supportsAlternateIcons {
                    
                    Text(String(localized: "settings.appIcon.supported", comment: "Text for supported app icons"))
                        .foregroundColor(.green)
                } else {
                    
                    Text(String(localized: "settings.appIcon.unsupported", comment: "Text for unsupported app icons"))
                        .foregroundColor(.red)
                }
                
                VStack(spacing: 12) {
                    ForEach(AppIcon.allCases) { icon in
                        Button(action: {
                            testIcon(icon)
                        }) {
                            HStack {
                                AppIconFallbackView(icon: icon)
                                    .scaleEffect(0.6)
                                
                                VStack(alignment: .leading) {
                                    Text(icon.displayName)
                                        .font(.headline)
                                    Text(icon.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if icon == iconManager.currentIcon {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(iconManager.isChangingIcon)
                    }
                }
                
                Spacer()
            }
            .padding()
            .alert(String(localized: "common.error"), isPresented: $showingError) {
                
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
    
    private func testIcon(_ icon: AppIcon) {
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

#Preview {
    AppIconTestView()
}
