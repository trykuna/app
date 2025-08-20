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

    // Filename customization
    @State private var showingFilenameDialog = false
    @State private var customFilename = ""
    @State private var pendingUploadData: Data?
    @State private var pendingUploadMimeType = ""
    @State private var pendingUploadOriginalName = ""

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { showingSourceDialog = true }) {
                HStack {
                    Text("Add Attachment")
                    Spacer()
                    Image(systemName: "paperclip")
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .confirmationDialog("Add Attachment", isPresented: $showingSourceDialog) {
                Button("Photo Library") { showPhotoPicker = true }
                Button("Files") { showFileImporter = true }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item], onCompletion: handleFileSelection)
            .alert("Set Filename", isPresented: $showingFilenameDialog) {
                TextField("Filename", text: $customFilename)
                    .autocorrectionDisabled()
                Button("Upload") {
                    performUpload()
                }
                Button("Cancel", role: .cancel) {
                    clearPendingUpload()
                }
            } message: {
                Text("Enter a custom name for '\(pendingUploadOriginalName)'")
            }

            if isUploading {
                Divider()
                    .padding(.leading, 16)
                HStack {
                    ProgressView()
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            if let uploadError {
                Divider()
                    .padding(.leading, 16)
                HStack {
                    Text(uploadError)
                        .font(.footnote)
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
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
            #if DEBUG
            Log.app.debug("TaskAttachmentView: Loading photo data for task id=\(task.id, privacy: .public)")
            #endif

            guard let data = try await item.loadTransferable(type: Data.self) else {
                await MainActor.run {
                    uploadError = "Missing photo data"
                }
                return
            }

            #if DEBUG
            Log.app.debug("TaskAttachmentView: Loaded photo data, size: \(data.count, privacy: .public) bytes")
            #endif

            await MainActor.run {
                // Store the data and show filename dialog
                pendingUploadData = data
                pendingUploadMimeType = "image/jpeg"
                pendingUploadOriginalName = "photo.jpg"
                customFilename = "photo.jpg"
                showingFilenameDialog = true
            }
        } catch {
            #if DEBUG
            Log.app.error("TaskAttachmentView: Photo loading error: \(String(describing: error), privacy: .public)")
            #endif
            await MainActor.run {
                uploadError = error.localizedDescription
            }
        }
    }

    private func handleFileSelection(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            Task {
                do {
                    #if DEBUG
                    Log.app.debug("TaskAttachmentView: Loading file data for task id=\(task.id, privacy: .public)")
                    Log.app.debug("TaskAttachmentView: File URL: \(url.absoluteString, privacy: .public)")
                    #endif

                    let data = try Data(contentsOf: url)
                    let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"

                    #if DEBUG
                    Log.app.debug("TaskAttachmentView: File data loaded, size: \(data.count, privacy: .public) bytes")
                    Log.app.debug("TaskAttachmentView: File name: \(url.lastPathComponent, privacy: .public), MIME: \(mime, privacy: .public)")
                    #endif

                    await MainActor.run {
                        // Store the data and show filename dialog
                        pendingUploadData = data
                        pendingUploadMimeType = mime
                        pendingUploadOriginalName = url.lastPathComponent
                        customFilename = url.lastPathComponent
                        showingFilenameDialog = true
                    }
                } catch {
                    #if DEBUG
                    Log.app.error("TaskAttachmentView: File loading error: \(String(describing: error), privacy: .public)")
                    #endif
                    await MainActor.run {
                        uploadError = error.localizedDescription
                    }
                }
            }
        case .failure(let error):
            uploadError = error.localizedDescription
        }
    }

    private func performUpload() {
        guard let data = pendingUploadData else {
            uploadError = "No file data available"
            return
        }

        // Ensure filename has an extension
        let finalFilename = ensureFileExtension(customFilename, mimeType: pendingUploadMimeType, originalName: pendingUploadOriginalName)

        Task {
            do {
                isUploading = true
                defer {
                    isUploading = false
                    clearPendingUpload()
                }

                #if DEBUG
                Log.app.debug("TaskAttachmentView: Starting upload with custom filename: \(finalFilename, privacy: .public)")
                #endif

                try await api.uploadAttachment(taskId: task.id, fileName: finalFilename, data: data, mimeType: pendingUploadMimeType)

                #if DEBUG
                Log.app.debug("TaskAttachmentView: Upload completed successfully")
                #endif

                await MainActor.run {
                    onUpload?()
                }
            } catch {
                #if DEBUG
                Log.app.error("TaskAttachmentView: Upload error: \(String(describing: error), privacy: .public)")
                #endif
                await MainActor.run {
                    uploadError = error.localizedDescription
                }
            }
        }
    }

    private func clearPendingUpload() {
        pendingUploadData = nil
        pendingUploadMimeType = ""
        pendingUploadOriginalName = ""
        customFilename = ""
    }

    private func ensureFileExtension(_ filename: String, mimeType: String, originalName: String) -> String {
        // If filename already has an extension, use it as-is
        if filename.contains(".") {
            return filename
        }

        // Try to get extension from original filename
        if let originalExtension = originalName.split(separator: ".").last {
            return "\(filename).\(originalExtension)"
        }

        // Fallback: guess extension from MIME type
        let fileExtension = extensionFromMimeType(mimeType)
        return "\(filename).\(fileExtension)"
    }

    private func extensionFromMimeType(_ mimeType: String) -> String {
        switch mimeType {
        case "image/jpeg": return "jpg"
        case "image/png": return "png"
        case "image/gif": return "gif"
        case "image/webp": return "webp"
        case "text/plain": return "txt"
        case "application/pdf": return "pdf"
        case "application/json": return "json"
        case "application/zip": return "zip"
        default: return "bin"
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
