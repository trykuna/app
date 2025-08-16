// Features/Tasks/TaskAttachmentView.swift
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct TaskAttachmentView: View {
    let task: VikunjaTask
    let api: VikunjaAPI
    var onUpload: (() -> Void)? = nil

    @State private var showingSourceDialog = false
    @State private var showPhotoPicker = false
    @State private var showFileImporter = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploading = false
    @State private var uploadError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Add Attachment") {
                showingSourceDialog = true
            }
            .confirmationDialog("Add Attachment", isPresented: $showingSourceDialog) {
                Button("Photo Library") { showPhotoPicker = true }
                Button("Files") { showFileImporter = true }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item], onCompletion: handleFileSelection)

            if isUploading {
                ProgressView()
            }

            if let uploadError {
                Text(uploadError)
                    .font(.footnote)
                    .foregroundColor(.red)
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            if let item = newValue {
                Task { await handlePhoto(item) }
            }
        }
    }

    private func handlePhoto(_ item: PhotosPickerItem) async {
        do {
            isUploading = true
            defer { isUploading = false }

            guard let data = try await item.loadTransferable(type: Data.self) else {
                uploadError = "Missing photo data"
                return
            }
            try await api.uploadAttachment(taskId: task.id, fileName: "photo.jpg", data: data, mimeType: "image/jpeg")
            onUpload?()
        } catch {
            uploadError = error.localizedDescription
        }
    }

    private func handleFileSelection(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            Task {
                do {
                    isUploading = true
                    defer { isUploading = false }
                    let data = try Data(contentsOf: url)
                    let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
                    try await api.uploadAttachment(taskId: task.id, fileName: url.lastPathComponent, data: data, mimeType: mime)
                    onUpload?()
                } catch {
                    uploadError = error.localizedDescription
                }
            }
        case .failure(let error):
            uploadError = error.localizedDescription
        }
    }
}

#if DEBUG
struct TaskAttachmentView_Previews: PreviewProvider {
    static var previews: some View {
        let task = VikunjaTask(id: 1, title: "Demo")
        let api = VikunjaAPI(config: VikunjaConfig(baseURL: URL(string: "https://example.com")!), tokenProvider: { nil })
        TaskAttachmentView(task: task, api: api)
            .padding()
    }
}
#endif
