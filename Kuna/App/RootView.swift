// App/RootView.swift
import SwiftUI

struct RootView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        if app.isAuthenticated, let api = app.api {
            MainContainerView(api: api)
        } else {
            LoginView()
        }
    }
}
