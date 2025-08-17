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
                    Text("Related Tasks")
                        .font(.body)
                        .foregroundColor(.primary)
                    let count = (task.relations ?? []).count
                    Text(count == 0 ? "No related tasks" : "\(count) related")
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

