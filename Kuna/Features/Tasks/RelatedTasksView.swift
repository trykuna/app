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

    // Navigation to a related task detail
    @State private var pushTarget: VikunjaTask?
    @State private var isPushing = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Hidden NavigationLink to push TaskDetailView
                NavigationLink(isActive: $isPushing) {
                    if let t = pushTarget {
                        TaskDetailView(task: t, api: api)
                    } else { EmptyView() }
                } label: { EmptyView() }

                content
                addBar
            }
            .navigationTitle("Related Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button { Task { await refresh() } } label: { Image(systemName: "arrow.clockwise") } }
            }
        }
        .onAppear { Task { await refresh() } }
        .alert("Error", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    @ViewBuilder
    private var content: some View {
        let relations = task.relations ?? []
        if isRefreshing && relations.isEmpty {
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.2)
                Text("Loading related tasks...").foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if relations.isEmpty {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "link").font(.system(size: 48)).foregroundColor(.secondary)
                Text("No Related Tasks").font(.title3).fontWeight(.semibold)
                Text("Use the picker below to relate another task.")
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
                if let due = rel.otherTask?.dueDate { Text(due, style: .date).font(.caption).foregroundColor(.secondary) }
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
                Picker("Kind", selection: $selectedKind) {
                    ForEach(TaskRelationKind.allCases.filter { $0 != .unknown }, id: \.self) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    showingPicker = true
                } label: {
                    HStack(spacing: 6) { Image(systemName: "text.magnifyingglass"); Text("Pick Task") }
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
            pushTarget = t
            isPushing = true
        } else {
            Task { await loadAndPush(rel) }
        }
    }

    private func loadAndPush(_ rel: TaskRelation) async {
        do {
            let full = try await api.getTask(taskId: rel.otherTaskId)
            await MainActor.run {
                self.pushTarget = full
                self.isPushing = true
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

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

