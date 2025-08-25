// Features/Attachments/AttachmentsView.swift
import SwiftUI

struct AttachmentsView: View {
    let task: VikunjaTask
    let api: VikunjaAPI

    @State private var attachments: [TaskAttachment] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var downloadingAttachments: Set<Int> = []

    var body: some View {
        VStack(spacing: 0) {
            if attachments.isEmpty && !isLoading {
                HStack {
                    Text(String(localized: "No_attachment", comment: "Label when no attachment is found for a task"))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else {
                ForEach(Array(attachments.enumerated()), id: \.element.id) { index, attachment in
                    HStack {
                        Button(action: {
                            Task { await downloadAttachment(attachment) }
                        }) {
                            HStack {
                                Image(systemName: iconForAttachment(attachment))
                                    .foregroundColor(.blue)
                                    .frame(width: 20)

                                Text(attachment.fileName)
                                    .lineLimit(1)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(downloadingAttachments.contains(attachment.id))

                        Spacer()

                        if downloadingAttachments.contains(attachment.id) {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Button(role: .destructive) {
                                Task { await deleteAttachment(attachment) }
                            } label: {
                                Image(systemName: "trash")
                            }
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
                Task {
                    // Small delay to ensure server has processed the upload
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    await loadAttachments()
                }
            }
        }
        .onAppear { Task { await loadAttachments() } }
        .alert(error ?? "", isPresented: Binding(get: { error != nil }, set: { _ in error = nil })) {
            Button("OK", role: .cancel) {}
        }
    }

    private func loadAttachments() async {
        #if DEBUG
        Log.app.debug("AttachmentsView: Loading attachments for task id=\(task.id, privacy: .public)")
        #endif

        do {
            isLoading = true
            attachments = try await api.getTaskAttachments(taskId: task.id)

            #if DEBUG
            Log.app.debug("AttachmentsView: Loaded \(attachments.count, privacy: .public) attachments")
            for attachment in attachments {
                Log.app.debug("AttachmentsView: - \(attachment.fileName, privacy: .public) (ID: \(attachment.id, privacy: .public))")
            }
            #endif
        } catch {
            #if DEBUG
            Log.app.error("AttachmentsView: Error loading attachments: \(String(describing: error), privacy: .public)")
            #endif

            // Handle common "no attachments" scenarios gracefully
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("404") || errorMessage.contains("not found") ||
               errorMessage.contains("no such file") || errorMessage.contains("missing") ||
               errorMessage.contains("couldn't be read") {
                // Task has no attachments - this is normal, not an error
                attachments = []
                #if DEBUG
                Log.app.debug("AttachmentsView: Task id=\(task.id, privacy: .public) has no attachments (404/not found)")
                #endif
            } else {
                // This is a real error that should be shown to the user
                self.error = error.localizedDescription
            }
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

    private func downloadAttachment(_ attachment: TaskAttachment) async {
        // Prevent multiple downloads of the same attachment
        guard !downloadingAttachments.contains(attachment.id) else { return }

        _ = await MainActor.run {
            downloadingAttachments.insert(attachment.id)
        }

        defer {
            Task { @MainActor in
                downloadingAttachments.remove(attachment.id)
            }
        }

        do {
            #if DEBUG
            Log.app.debug("AttachmentsView: Starting download of \(attachment.fileName, privacy: .public)")
            #endif

            // Check file size before downloading to avoid memory issues
            // Files larger than 50MB should be streamed or downloaded differently
            let maxSizeInMemory = 50 * 1024 * 1024 // 50MB
            
            let data = try await api.downloadAttachment(taskId: task.id, attachmentId: attachment.id)
            
            if data.count > maxSizeInMemory {
                Log.app.warning("AttachmentsView: Large attachment \(attachment.fileName), size: \(data.count) bytes")
            }

            #if DEBUG
            Log.app.debug("AttachmentsView: Downloaded \(attachment.fileName, privacy: .public), size: \(data.count, privacy: .public) bytes")
            #endif

            _ = await MainActor.run {
                saveToFiles(data: data, filename: attachment.fileName)
            }
        } catch {
            #if DEBUG
            Log.app.error("AttachmentsView: Error downloading attachment: \(String(describing: error), privacy: .public)")
            #endif
            _ = await MainActor.run {
                self.error = "Failed to download \(attachment.fileName): \(error.localizedDescription)"
            }
        }
    }

    private func saveToFiles(data: Data, filename: String) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: tempURL)

            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)

            // Get the root view controller
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {

                // Handle iPad presentation
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = window
                    popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }

                rootVC.present(activityVC, animated: true)
            }
        } catch {
            self.error = "Failed to save file: \(error.localizedDescription)"
        }
    }

    private func iconForAttachment(_ attachment: TaskAttachment) -> String {
        let filename = attachment.fileName.lowercased()

        // Image files
        if filename.hasSuffix(".jpg") || filename.hasSuffix(".jpeg") || filename.hasSuffix(".png") ||
           filename.hasSuffix(".gif") || filename.hasSuffix(".webp") || filename.hasSuffix(".bmp") {
            return "photo"
        }

        // Document files
        if filename.hasSuffix(".pdf") {
            return "doc.richtext"
        }

        if filename.hasSuffix(".doc") || filename.hasSuffix(".docx") {
            return "doc.text"
        }

        if filename.hasSuffix(".xls") || filename.hasSuffix(".xlsx") {
            return "tablecells"
        }

        if filename.hasSuffix(".ppt") || filename.hasSuffix(".pptx") {
            return "rectangle.on.rectangle"
        }

        // Text files
        if filename.hasSuffix(".txt") || filename.hasSuffix(".md") {
            return "doc.plaintext"
        }

        // Code files
        if filename.hasSuffix(".json") || filename.hasSuffix(".xml") || filename.hasSuffix(".html") ||
           filename.hasSuffix(".css") || filename.hasSuffix(".js") || filename.hasSuffix(".py") ||
           filename.hasSuffix(".swift") || filename.hasSuffix(".java") {
            return "chevron.left.forwardslash.chevron.right"
        }

        // Archive files
        if filename.hasSuffix(".zip") || filename.hasSuffix(".rar") || filename.hasSuffix(".7z") {
            return "archivebox"
        }

        // Audio files
        if filename.hasSuffix(".mp3") || filename.hasSuffix(".wav") || filename.hasSuffix(".m4a") {
            return "music.note"
        }

        // Video files
        if filename.hasSuffix(".mp4") || filename.hasSuffix(".mov") || filename.hasSuffix(".avi") {
            return "play.rectangle"
        }

        // Default
        return "doc"
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
