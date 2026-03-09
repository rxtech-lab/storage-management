import RxStorageCore
import SwiftUI

struct ContentUploadProgressSheet: View {
    let itemId: String
    let itemTitle: String
    let onClose: () -> Void
    var onUploadFiles: (() -> Void)?
    var onUploadFolder: (() -> Void)?
    var uploadCenter: ContentUploadCenterViewModel
    @State private var expandedLogFileIDs: Set<UUID> = []
    @State private var selectedMode: ContentUploadVideoMode = .imageOnly

    private var session: ContentUploadSession? {
        uploadCenter.session(for: itemId)
    }

    var body: some View {
        Group {
            if let session {
                if session.status == .idle {
                    idleStateView(session)
                } else {
                    uploadingStateView(session)
                }
            } else {
                unavailableStateView
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if session == nil || session?.status == .idle {
                    Button("Cancel") {
                        if let session, session.status == .idle {
                            uploadCenter.removeSession(for: itemId)
                        }
                        onClose()
                    }
                    .accessibilityIdentifier("upload-cancel-button")
                } else if session?.status == .running || session?.status == .paused {
                    Button("Close") {
                        onClose()
                    }
                    .accessibilityIdentifier("upload-close-button")
                }
            }

            ToolbarItem(placement: .automatic) {
                if let session, session.status == .completed || session.status == .stopped {
                    Menu {
                        Button {
                            uploadCenter.removeSession(for: itemId)
                            onUploadFiles?()
                        } label: {
                            Label("Upload Files", systemImage: "arrow.up.doc")
                        }
                        .accessibilityIdentifier("new-upload-files-button")

                        Button {
                            uploadCenter.removeSession(for: itemId)
                            onUploadFolder?()
                        } label: {
                            Label("Upload Folder", systemImage: "folder.badge.plus")
                        }
                        .accessibilityIdentifier("new-upload-folder-button")
                    } label: {
                        Label("New Upload", systemImage: "plus")
                    }
                    .accessibilityIdentifier("new-upload-menu")
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                if let session, session.status == .idle {
                    Button("Upload") {
                        uploadCenter.beginUpload(itemId: itemId, mode: session.hasVideoFiles ? selectedMode : .imageOnly)
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .accessibilityIdentifier("upload-start-button")
                } else if let session, session.status == .completed || session.status == .stopped {
                    Button("Done") {
                        uploadCenter.removeSession(for: itemId)
                        onClose()
                    }
                    .accessibilityIdentifier("upload-done-button")
                }
            }
        }
    }

    // MARK: - Idle State (Pre-Upload)

    private func idleStateView(_ session: ContentUploadSession) -> some View {
        VStack(spacing: 0) {
            // Header
            idleHeader(session)

            Divider()

            // File List
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(session.files) { file in
                        idleFileRow(file)
                    }
                }
                .padding(.vertical, 8)
            }

            Divider()

            // Footer with Upload Options
            idleFooter(session)
        }
        .background(.background)
    }

    private func idleHeader(_ session: ContentUploadSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Upload to \(itemTitle)")
                    .font(.headline)
                Text("\(session.totalCount) files ready")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // File type summary
            HStack(spacing: 16) {
                let imageCount = session.files.filter { $0.inputFile.mediaType == .image }.count
                let videoCount = session.files.filter { $0.inputFile.mediaType == .video }.count
                let totalSize = session.files.reduce(0) { $0 + $1.inputFile.fileSize }

                if imageCount > 0 {
                    Label("\(imageCount) images", systemImage: "photo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if videoCount > 0 {
                    Label("\(videoCount) videos", systemImage: "video")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Label(formattedSize(totalSize), systemImage: "internaldrive")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .padding(16)
    }

    private func idleFileRow(_ file: ContentUploadFileProgress) -> some View {
        HStack(spacing: 12) {
            // File type icon
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(file.inputFile.mediaType == .video ? Color.purple.opacity(0.15) : Color.blue.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: file.inputFile.mediaType == .video ? "video.fill" : "photo.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(file.inputFile.mediaType == .video ? .purple : .blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(file.inputFile.filename)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if file.inputFile.relativePath != file.inputFile.filename {
                        Text(file.inputFile.relativePath)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                    Text(formattedSize(file.inputFile.fileSize))
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(file.inputFile.extensionName.uppercased())
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func idleFooter(_ session: ContentUploadSession) -> some View {
        if session.hasVideoFiles {
            // Upload mode selection
            VStack(alignment: .leading, spacing: 10) {
                Text("Upload Mode")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 12) {
                    uploadModeCard(
                        mode: .imageOnly,
                        title: "Thumbnails Only",
                        description: "Generate preview images",
                        icon: "photo.stack",
                        isSelected: selectedMode == .imageOnly
                    )

                    uploadModeCard(
                        mode: .videoAndImage,
                        title: "Video + Thumbnails",
                        description: "Upload full video files",
                        icon: "video.badge.plus",
                        isSelected: selectedMode == .videoAndImage
                    )
                }
            }
            .padding(16)
        }
    }

    private func uploadModeCard(
        mode: ContentUploadVideoMode,
        title: String,
        description: String,
        icon: String,
        isSelected: Bool
    ) -> some View {
        Button {
            selectedMode = mode
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(isSelected ? .white : .secondary)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(isSelected ? .white : .primary)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            #if os(macOS)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.accentColor : Color(.controlBackgroundColor))
                )
            #endif
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(isSelected ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Uploading State

    private func uploadingStateView(_ session: ContentUploadSession) -> some View {
        VStack(spacing: 0) {
            // Progress Header
            uploadingHeader(session)

            Divider()

            // File List with Progress
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(session.files) { file in
                        uploadingFileRow(file, sessionStatus: session.status)
                    }
                }
                .padding(.vertical, 8)
            }

            // Footer (shown only for completed/stopped states)
            if session.status == .completed || session.status == .stopped {
                Divider()
                completedFooter(session)
            }
        }
        .background(.background)
    }

    private func uploadingHeader(_ session: ContentUploadSession) -> some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(headerTitle(for: session.status))
                        .font(.headline)

                    if session.status == .running {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                Text(headerSubtitle(for: session))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Overall progress
            VStack(spacing: 8) {
                HStack {
                    Text("\(session.completedCount) of \(session.totalCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(Int(session.overallProgress * 100))%")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                }

                // Progress bar with controls
                HStack(spacing: 12) {
                    ProgressView(value: session.overallProgress)
                        .progressViewStyle(.linear)
                        .tint(progressColor(for: session.status))

                    // Inline control buttons
                    if session.status == .running {
                        HStack(spacing: 8) {
                            Button {
                                uploadCenter.pauseUpload(itemId: itemId)
                            } label: {
                                Image(systemName: "pause.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, height: 28)
                                    .background(.quaternary, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Pause")

                            Button {
                                uploadCenter.stopUploadCompletely(itemId: itemId)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .frame(width: 28, height: 28)
                                    .background(.quaternary, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Stop")
                        }
                    } else if session.status == .paused {
                        HStack(spacing: 8) {
                            Button {
                                uploadCenter.beginUpload(itemId: itemId, mode: session.videoMode ?? .imageOnly)
                            } label: {
                                Image(systemName: "play.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 28, height: 28)
                                    .background(.quaternary, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Resume")

                            Button {
                                uploadCenter.stopUploadCompletely(itemId: itemId)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .frame(width: 28, height: 28)
                                    .background(.quaternary, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Stop")
                        }
                    }
                }
            }

            // Stats row
            HStack(spacing: 0) {
                statPill(value: session.succeededCount, label: "Succeeded", color: .green)
                Spacer()
                statPill(value: session.failedCount, label: "Failed", color: session.failedCount > 0 ? .red : .secondary)
                Spacer()
                statPill(value: session.cancelledCount, label: "Cancelled", color: session.cancelledCount > 0 ? .orange : .secondary)
                Spacer()
                statPill(value: session.totalCount - session.completedCount, label: "Remaining", color: .secondary)
            }
        }
        .padding(16)
    }

    private func uploadingFileRow(_ file: ContentUploadFileProgress, sessionStatus _: ContentUploadSessionStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Status icon
                statusIcon(for: file.status)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(file.inputFile.filename)
                        .font(.body)
                        .lineLimit(1)

                    Text(file.status.displayText)
                        .font(.caption)
                        .foregroundStyle(statusTextColor(for: file.status))
                }

                Spacer()

                if file.status.isInProgress {
                    Text("\(Int(file.progress * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            // Individual progress bar (only show when in progress)
            if file.status.isInProgress {
                ProgressView(value: file.progress)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
            }

            // Error details
            if let errorMessage = file.errorMessage, !errorMessage.isEmpty,
               case .failed = file.status
            {
                VStack(alignment: .leading, spacing: 6) {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)

                    if let logMessage = file.logMessage, !logMessage.isEmpty {
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { expandedLogFileIDs.contains(file.id) },
                                set: { isExpanded in
                                    if isExpanded {
                                        expandedLogFileIDs.insert(file.id)
                                    } else {
                                        expandedLogFileIDs.remove(file.id)
                                    }
                                }
                            )
                        ) {
                            ScrollView(.vertical) {
                                Text(logMessage)
                                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 120)
                            .padding(8)
                            .background(.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        } label: {
                            Text("View Log")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.leading, 36)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(file.status.isInProgress ? Color.accentColor.opacity(0.05) : Color.clear)
    }

    @ViewBuilder
    private func statusIcon(for status: ContentUploadFileStatus) -> some View {
        switch status {
        case .succeeded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
        case .cancelled:
            Image(systemName: "minus.circle.fill")
                .foregroundStyle(.orange)
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(.quaternary)
        case .preprocessing, .requestingUploadURL, .uploadingThumbnail, .uploadingVideo:
            ProgressView()
                .controlSize(.small)
        }
    }

    private func completedFooter(_ session: ContentUploadSession) -> some View {
        HStack {
            if session.status == .completed {
                Label(
                    session.failedCount > 0
                        ? "Completed with \(session.failedCount) error\(session.failedCount == 1 ? "" : "s")"
                        : "All files uploaded successfully",
                    systemImage: session.failedCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
                )
                .font(.subheadline)
                .foregroundStyle(session.failedCount > 0 ? .orange : .green)
            } else {
                Label("Upload stopped", systemImage: "stop.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
    }

    // MARK: - Unavailable State

    private var unavailableStateView: some View {
        ContentUnavailableView(
            "No Upload Session",
            systemImage: "tray",
            description: Text("Start an upload from the Add Content menu.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    // MARK: - Helper Views

    private func statPill(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helper Functions

    private func headerTitle(for status: ContentUploadSessionStatus) -> String {
        switch status {
        case .idle: return "Ready to Upload"
        case .running: return "Uploading..."
        case .paused: return "Paused"
        case .completed: return "Upload Complete"
        case .stopped: return "Upload Stopped"
        }
    }

    private func headerSubtitle(for session: ContentUploadSession) -> String {
        if let mode = session.videoMode {
            return mode.displayName
        }
        return "\(session.totalCount) files"
    }

    private func progressColor(for status: ContentUploadSessionStatus) -> Color {
        switch status {
        case .running: return .accentColor
        case .paused: return .orange
        case .completed: return .green
        case .stopped: return .red
        case .idle: return .secondary
        }
    }

    private func statusTextColor(for status: ContentUploadFileStatus) -> Color {
        switch status {
        case .succeeded: return .green
        case .failed: return .red
        case .cancelled: return .orange
        case .pending: return .secondary
        case .preprocessing, .requestingUploadURL, .uploadingThumbnail, .uploadingVideo: return .accentColor
        }
    }

    private func formattedSize(_ byteCount: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: byteCount)
    }
}

struct FolderExtensionInputSheet: View {
    @Binding var extensionInput: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Filter Folder Files")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Enter comma-separated extensions to include")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("jpg,jpeg,png,mp4", text: $extensionInput)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Close") {
                    onCancel()
                }
                Spacer()
                Button("Continue") {
                    onConfirm()
                }
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}

// MARK: - Preview

#Preview("No Session") {
    ContentUploadProgressSheet(
        itemId: "preview-item",
        itemTitle: "Sample Item",
        onClose: {},
        uploadCenter: ContentUploadCenterViewModel()
    )
}
