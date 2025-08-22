// Features/Navigation/SideMenuView.swift
import SwiftUI

struct SideMenuView: View {
    let api: VikunjaAPI
    @EnvironmentObject var appState: AppState
    @Binding var selectedMenuItem: MenuItem
    @Binding var isMenuOpen: Bool
    
    enum MenuItem: String, CaseIterable {
        case favorites = "Favorites"
        case projects = "Projects"
        case labels = "Labels"
        case settings = "Settings"

        var systemImage: String {
            switch self {
            case .favorites: return "star.fill"
            case .projects: return "folder"
            case .labels: return "tag"
            case .settings: return "gear"
            }
        }

        var color: Color {
            switch self {
            case .favorites: return .yellow
            case .projects: return .blue
            case .labels: return .green
            case .settings: return .gray
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    AdaptiveLogo(.main)
                        .logoSize(40)
                        .logoCornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Kuna")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        if let serverURL = Keychain.readServerURL() {
                            Text(URL(string: serverURL)?.host ?? serverURL)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 10)
            }
            .background(Color(.systemGroupedBackground))
            
            Divider()
            
            // Menu Items
            VStack(spacing: 0) {
                // Main menu items
                ForEach([MenuItem.favorites, MenuItem.projects, MenuItem.labels], id: \.self) { item in
                    menuItem(item)
                }
                
                Spacer()
                
                // Settings at bottom
                menuItem(.settings)
            }
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 2, y: 0)
    }
    
    private func menuItem(_ item: MenuItem) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedMenuItem = item
            }
            withAnimation(.easeInOut(duration: 0.3)) {
                isMenuOpen = false
            }
        }) {
            HStack(spacing: 16) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(selectedMenuItem == item ? item.color : item.color.opacity(0.7))
                    .frame(width: 24, height: 24)
                
                Text(item.rawValue)
                    .font(.body)
                    .fontWeight(selectedMenuItem == item ? .semibold : .regular)
                    .foregroundColor(selectedMenuItem == item ? .accentColor : .primary)
                
                Spacer()
                
                if selectedMenuItem == item {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .frame(width: 3, height: 24)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                selectedMenuItem == item ? 
                Color.accentColor.opacity(0.1) : 
                Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("Sidebar.\(item.rawValue)")
    }
}

#Preview {
    SideMenuView(
        api: VikunjaAPI(config: .init(baseURL: URL(string: "https://example.com")!), tokenProvider: { nil }),
        selectedMenuItem: .constant(.projects),
        isMenuOpen: .constant(true)
    )
    .environmentObject(AppState())
}
