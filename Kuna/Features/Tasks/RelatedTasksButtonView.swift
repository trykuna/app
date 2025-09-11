// Features/Tasks/RelatedTasksButtonView.swift
import SwiftUI

struct RelatedTasksButtonView: View {
    @Binding var task: VikunjaTask
    let api: VikunjaAPI

    @State private var showing = false

    var body: some View {
        Button {
            showing = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    
                    Text(String(localized: "tasks.details.relatedTasks.title", comment: "Title for related tasks"))
                        .font(.body)
                        .foregroundColor(.primary)
                        let relations = task.relations ?? []
                        Text(relations.isEmpty
                                ? String(localized: "tasks.related.none", comment: "No related tasks")
                                : "\(relations.count) related")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "link")
                    .foregroundColor(.blue)
                    .font(.title3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showing) {
            RelatedTasksView(task: $task, api: api)
        }
    }
}
