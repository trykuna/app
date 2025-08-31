// Features/Labels/LabelsViewModel.swift
import SwiftUI
import Foundation

@MainActor
final class LabelsViewModel: ObservableObject {
    @Published var labels: [Label] = []
    @Published var loading = false
    @Published var error: String?
    
    private let api: VikunjaAPI
    
    init(api: VikunjaAPI) {
        self.api = api
    }
    
    func load() async {
        loading = true
        error = nil
        
        do {
            labels = try await api.fetchLabels()
        } catch {
            self.error = error.localizedDescription
        }
        
        loading = false
    }
    
    func createLabel(title: String, hexColor: String, description: String?) async -> Bool {
        do {
            let newLabel = try await api.createLabel(title: title, hexColor: hexColor, description: description)
            labels.append(newLabel)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
    
    func updateLabel(_ label: Label, title: String, hexColor: String, description: String?) async -> Bool {
        do {
            let updatedLabel = try await api.updateLabel(
                labelId: label.id,
                title: title,
                hexColor: hexColor,
                description: description
            )
            if let index = labels.firstIndex(where: { $0.id == label.id }) {
                labels[index] = updatedLabel
            }
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
    
    func deleteLabel(_ label: Label) async -> Bool {
        do {
            try await api.deleteLabel(labelId: label.id)
            labels.removeAll { $0.id == label.id }
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
