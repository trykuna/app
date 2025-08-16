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
                Text("App Icon Test")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Current Icon: \(iconManager.currentIcon.displayName)")
                    .font(.headline)
                
                if iconManager.supportsAlternateIcons {
                    Text("✅ Alternate icons are supported")
                        .foregroundColor(.green)
                } else {
                    Text("❌ Alternate icons are not supported")
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
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
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
                        Text("Changing Icon...")
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
