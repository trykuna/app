// Features/Labels/LabelsView.swift
import SwiftUI

struct LabelsView: View {
    @StateObject private var viewModel: LabelsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingCreateLabel = false
    @State private var showingEditLabel = false
    @State private var selectedLabel: Label?
    @State private var showingDeleteAlert = false
    @State private var labelToDelete: Label?
    
    init(api: VikunjaAPI) {
        _viewModel = StateObject(wrappedValue: LabelsViewModel(api: api))
    }
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.loading {
                    ProgressView("Loading labels...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.labels.isEmpty {
                    emptyStateView
                } else {
                    labelsList
                }
            }
            .navigationTitle("Labels")
            .navigationBarTitleDisplayMode(.large)
            .accessibilityIdentifier("screen.labels")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateLabel = true }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("button.addLabel")
                }
            }
            .sheet(isPresented: $showingCreateLabel) {
                CreateLabelView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingEditLabel) {
                if let label = selectedLabel {
                    EditLabelView(viewModel: viewModel, label: label)
                }
            }
            .alert("Delete Label", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let label = labelToDelete {
                        Task {
                            await viewModel.deleteLabel(label)
                        }
                    }
                }
            } message: {
                if let label = labelToDelete {
                    Text("Are you sure you want to delete '\(label.title)'? This action cannot be undone.")
                }
            }
            .task {
                await viewModel.load()
            }
            .overlay {
                if let error = viewModel.error {
                    VStack {
                        Text("Error")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Retry") {
                            Task { await viewModel.load() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 4)
                    .padding()
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tag")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.6))
            
            Text("No Labels")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create your first label to organize your tasks")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Create Label") {
                showingCreateLabel = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var labelsList: some View {
        List {
            ForEach(viewModel.labels) { label in
                labelRow(label)
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private func labelRow(_ label: Label) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(label.color)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.2), lineWidth: 0.5)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label.title)
                    .font(.body)
                    .fontWeight(.medium)
                
                if let description = label.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Menu {
                Button(action: {
                    selectedLabel = label
                    showingEditLabel = true
                }) {
                    SwiftUI.Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive, action: {
                    labelToDelete = label
                    showingDeleteAlert = true
                }) {
                    SwiftUI.Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("label.row")
    }
}

#Preview {
    LabelsView(api: VikunjaAPI(config: .init(baseURL: URL(string: "https://example.com")!), tokenProvider: { nil }))
}
