// Features/Attachments/AttachmentsView.swift
import SwiftUI

struct AttachmentsView: View {
    let task: VikunjaTask
    let api: VikunjaAPI

    @State private var attachments: [TaskAttachment] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            if attachments.isEmpty && !isLoading {
                HStack {
                    Text("No attachments")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else {
                ForEach(Array(attachments.enumerated()), id: \.element.id) { index, attachment in
                    HStack {
                        Text(attachment.fileName)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                        Spacer()
                        Button(role: .destructive) {
                            Task { await deleteAttachment(attachment) }
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if index < attachments.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }

                if isLoading {
                    Divider()
                        .padding(.leading, 16)
                    HStack {
                        ProgressView()
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }

            Divider()
                .padding(.leading, 16)

            TaskAttachmentView(task: task, api: api) {
                Task { await loadAttachments() }
            }
        }
        .onAppear { Task { await loadAttachments() } }
        .alert(error ?? "", isPresented: Binding(get: { error != nil }, set: { _ in error = nil })) {
            Button("OK", role: .cancel) {}
        }
    }

    private func loadAttachments() async {
        do {
            isLoading = true
            attachments = try await api.getTaskAttachments(taskId: task.id)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func deleteAttachment(_ attachment: TaskAttachment) async {
        do {
            try await api.deleteAttachment(taskId: task.id, attachmentId: attachment.id)
            await loadAttachments()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#if DEBUG
struct AttachmentsView_Previews: PreviewProvider {
    static var previews: some View {
        let task = VikunjaTask(id: 1, title: "Demo")
        let api = VikunjaAPI(config: VikunjaConfig(baseURL: URL(string: "https://example.com")!), tokenProvider: { nil })
        AttachmentsView(task: task, api: api)
            .padding()
    }
}
#endif
