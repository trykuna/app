// App/RootView.swift
import SwiftUI

struct RootView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        if app.isAuthenticated, let api = app.api {
            ProjectListView(api: api)
        } else {
            LoginView()
        }
    }
}
