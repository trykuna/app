// Features/Settings/LabelWatchListView.swift
import SwiftUI

struct LabelWatchListView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var settings: AppSettings

    @State private var labels: [Label] = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        List {
            if loading { ProgressView().frame(maxWidth: .infinity, alignment: .center) }
            if let error { Text(error).foregroundColor(.red) }
            ForEach(labels) { label in
                let selected = settings.watchedLabelIDs.contains(label.id)
                Button(action: { toggle(label.id) }) {
                    HStack {
                        Circle().fill(Color(hex: label.hexColor ?? "#999999")).frame(width: 14, height: 14)
                        Text(label.title)
                        Spacer()
                        if selected { Image(systemName: "checkmark").foregroundColor(.accentColor) }
                    }
                }
            }
        }
        .navigationTitle("Watched Labels")
        .onAppear(perform: load)
    }

    private func load() {
        guard let api = appState.api else { return }
        loading = true
        Task {
            do {
                let ls = try await api.fetchLabels()
                await MainActor.run { labels = ls; loading = false }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; loading = false }
            }
        }
    }

    private func toggle(_ id: Int) {
        if let idx = settings.watchedLabelIDs.firstIndex(of: id) {
            settings.watchedLabelIDs.remove(at: idx)
        } else {
            settings.watchedLabelIDs.append(id)
        }
    }
}

