import Foundation
import OpenAPIRuntime
import SwiftTUI

struct UploadContentView: View, @unchecked Sendable {
    let itemId: String

    @State var step: UploadStep = .enterPath
    @State var directoryPath = ""
    @State var extensions = ""
    @State var matchedFiles: [FileEntry] = []
    @State var videoUploadMode: VideoUploadMode = .imageOnly
    @State var uploadProgress = 0
    @State var uploadTotal = 0
    @State var errorMessage: String?
    @State var uploadResults: [UploadResult] = []
    @State var isoMountPoint: String?

    var body: some View {
        VStack(alignment: .leading) {
            Text("Upload Content Preview").bold()
            Text("Item: \(itemId)")
            Divider()

            switch step {
            case .enterPath:
                enterPathView
            case .enterExtensions:
                enterExtensionsView
            case .listFiles:
                listFilesView
            case .uploadOptions:
                uploadOptionsView
            case .uploading:
                uploadingView
            case .done:
                doneView
            }
        }
    }

    // MARK: - Step Views

    private var enterPathView: some View {
        VStack(alignment: .leading) {
            Text("Enter directory or ISO path:")
            TextField(placeholder: "/path/to/content or /path/to/file.iso") { path in
                let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.lowercased().hasSuffix(".iso") {
                    if FileManager.default.fileExists(atPath: trimmed) {
                        if let mountPoint = ISOService.mount(isoPath: trimmed) {
                            isoMountPoint = mountPoint
                            directoryPath = mountPoint
                            step = .enterExtensions
                        } else {
                            errorMessage = "Failed to mount ISO: \(trimmed)"
                        }
                    } else {
                        errorMessage = "ISO file does not exist: \(trimmed)"
                    }
                } else {
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: trimmed, isDirectory: &isDir),
                        isDir.boolValue
                    {
                        directoryPath = trimmed
                        step = .enterExtensions
                    } else {
                        errorMessage = "Path does not exist or is not a directory: \(trimmed)"
                    }
                }
            }
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    private var enterExtensionsView: some View {
        VStack(alignment: .leading) {
            Text("Path: \(directoryPath)")
            Text("Enter file extensions (comma separated, e.g. jpg,png,mp4):")
            TextField(placeholder: "jpg,png,mp4") { exts in
                extensions = exts.trimmingCharacters(in: .whitespacesAndNewlines)
                scanFiles()
            }
        }
    }

    private var listFilesView: some View {
        VStack(alignment: .leading) {
            Text("Found \(matchedFiles.count) file(s):")
            Divider()
            ForEach(matchedFiles.prefix(5), id: \.path) { file in
                Text("  [\(file.type.rawValue)] \(file.filename)")
            }
            if matchedFiles.count > 5 {
                Text("  ... and \(matchedFiles.count - 5) more")
            }

            if matchedFiles.isEmpty {
                Text("No files match the given extensions.")
                Button("Back") { step = .enterExtensions }
            } else {
                Divider()
                let hasVideos = matchedFiles.contains { $0.type == .video }
                if hasVideos {
                    Button("Continue") { step = .uploadOptions }
                } else {
                    Button("Upload preview images") {
                        videoUploadMode = .imageOnly
                        startUpload()
                    }
                }
            }
        }
    }

    private var uploadOptionsView: some View {
        VStack(alignment: .leading) {
            let videoCount = matchedFiles.filter { $0.type == .video }.count
            let imageCount = matchedFiles.filter { $0.type == .image }.count
            Text("Files: \(imageCount) image(s), \(videoCount) video(s)")
            Divider()
            Text("For videos, choose upload mode:")
            Button("Video + preview image") {
                videoUploadMode = .videoAndImage
                startUpload()
            }
            Button("Preview image only (thumbnail)") {
                videoUploadMode = .imageOnly
                startUpload()
            }
        }
    }

    private var uploadingView: some View {
        VStack(alignment: .leading) {
            Text("Uploading... [\(uploadProgress)/\(uploadTotal)]")
            let barWidth = 30
            let filled = uploadTotal > 0 ? (uploadProgress * barWidth / uploadTotal) : 0
            let bar =
                String(repeating: "#", count: filled)
                + String(repeating: "-", count: barWidth - filled)
            Text("[\(bar)]")
            Text("Logs: \(AppLogger.logFileURL.path)")
            if let error = errorMessage {
                Text("Error: \(error)")
            }
        }
    }

    private var doneView: some View {
        VStack(alignment: .leading) {
            Text("Upload complete!")
            Text(
                "Uploaded \(uploadResults.filter { $0.success }.count)/\(uploadResults.count) file(s)"
            )
            Divider()
            ForEach(uploadResults, id: \.filename) { result in
                if result.success {
                    Text("  OK: \(result.filename)")
                } else {
                    Text("  FAIL: \(result.filename) - \(result.error ?? "unknown")")
                }
            }
        }
    }
}
