// Features/Favorites/FavoritesViewWithMenu.swift
import SwiftUI

struct FavoritesViewWithMenu: View {
    let api: VikunjaAPI
    @Binding var isMenuOpen: Bool
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            FavoritesView(api: api)
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isMenuOpen.toggle()
                            }
                        }) {
                            Image(systemName: "line.3.horizontal")
                                .font(.title2)
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingSettings = true
                        }) {
                            Image(systemName: "gear")
                                .font(.title2)
                        }
                    }
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView()
                }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

#Preview {
    FavoritesViewWithMenu(
        api: VikunjaAPI(config: .init(baseURL: URL(string: "https://example.com")!), // swiftlint:disable:this force_unwrapping
                            tokenProvider: { nil }),
        isMenuOpen: .constant(false)
    )
    .environmentObject(AppState())
}
