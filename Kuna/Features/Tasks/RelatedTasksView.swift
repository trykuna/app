// Features/Tasks/RelatedTasksView.swift
import SwiftUI

struct RelatedTasksView: View {
    @Binding var task: VikunjaTask
    let api: VikunjaAPI

    @Environment(\.dismiss) private var dismiss

    @State private var isRefreshing = false
    @State private var error: String?
    @State private var showingPicker = false
    @State private var selectedKind: TaskRelationKind = .related

    // Modern navigation (iOS 16+)
    @State private var navSelection: VikunjaTask?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                content
                addBar
            }
            // .navigationTitle("Related Tasks")
            .navigationTitle(String(localized: "tasks.related.title", comment: "Related tasks navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Button("Done") { dismiss() }
                    Button(String(localized: "common.done", comment: "Done button")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await refresh() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .navigationDestination(item: $navSelection) { t in
                TaskDetailView(task: t, api: api, onUpdate: nil)
            }
        }
        .onAppear { Task { await refresh() } }
        .alert(String(localized: "common.error"), isPresented: .constant(error != nil)) {
            // Button("OK") { error = nil }
            Button(String(localized: "common.ok", comment: "OK button")) { error = nil }
        } message: { Text(error ?? "") }
    }

    @ViewBuilder
    private var content: some View {
        let relations = task.relations ?? []
        if isRefreshing && relations.isEmpty {
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.2)
                Text(String(localized: "tasks.related.loading", comment: "Loading related tasks..."))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if relations.isEmpty {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "link").font(.system(size: 48)).foregroundColor(.secondary)
                // Text("No Related Tasks").font(.title3).fontWeight(.semibold)
                Text(String(localized: "tasks.related.none.title", comment: "No related tasks title"))
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(String(localized: "tasks.related.none.subtitle", comment: "Use the picker below to relate another task."))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(relations) { rel in
                        relationRow(rel)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemBackground))
            .refreshable { await refresh() }
        }
    }

    private func relationRow(_ rel: TaskRelation) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon(for: rel.relationKind))
                .foregroundColor(.blue)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(rel.relationKind.displayName).font(.subheadline).fontWeight(.medium)
                Text(rel.otherTask?.title ?? "Task #\(rel.otherTaskId)")
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                if let due = rel.otherTask?.dueDate {
                    Text(due, style: .date).font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            Button(role: .destructive) {
                Task { await remove(rel) }
            } label: { Image(systemName: "trash") }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture { handleRowTap(rel) }
    }

    private var addBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                // Picker("Kind", selection: $selectedKind) {
                Picker(String(localized: "tasks.relation.kind", comment: "Relation kind picker"), selection: $selectedKind) {
                    ForEach(TaskRelationKind.allCases.filter { $0 != .unknown }, id: \.self) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    showingPicker = true
                } label: {
                    HStack(spacing: 6) { 
                        Image(systemName: "text.magnifyingglass")
                        // Text("Pick Task")
                        Text(String(localized: "tasks.picker.title", comment: "Pick task button"))
                    }
                }
                .buttonStyle(.bordered)
                .sheet(isPresented: $showingPicker) {
                    TaskPickerSheet(api: api) { picked in
                        Task { await add(otherTaskId: picked.id) }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Actions

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let updated = try await api.getTask(taskId: task.id)
            await MainActor.run { self.task = updated }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    private func add(otherTaskId: Int) async {
        do {
            try await api.addTaskRelation(taskId: task.id, otherTaskId: otherTaskId, relationKind: selectedKind)
            await refresh()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    private func remove(_ rel: TaskRelation) async {
        do {
            try await api.removeTaskRelation(taskId: task.id, otherTaskId: rel.otherTaskId, relationKind: rel.relationKind)
            await refresh()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    private func handleRowTap(_ rel: TaskRelation) {
        if let t = rel.otherTask {
            // We already have the full task
            navSelection = t
        } else {
            // Fetch it first, then navigate
            Task { await loadAndPush(rel) }
        }
    }

    private func loadAndPush(_ rel: TaskRelation) async {
        do {
            let full = try await api.getTask(taskId: rel.otherTaskId)
            await MainActor.run { self.navSelection = full }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Helpers

    private func icon(for kind: TaskRelationKind) -> String {
        switch kind {
        case .subtask: return "list.bullet.indent"
        case .parenttask: return "rectangle.stack"
        case .related: return "link"
        case .duplicateof, .duplicates: return "square.on.square"
        case .blocking: return "hand.raised"
        case .blocked: return "hand.raised.fill"
        case .precedes: return "arrow.forward"
        case .follows: return "arrow.backward"
        case .copiedfrom, .copiedto: return "doc.on.doc"
        case .unknown: return "questionmark.circle"
        }
    }
}
