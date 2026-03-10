import Foundation
import Logging
import SwiftUI

public enum ContentUploadCenterError: LocalizedError {
    case noSupportedFiles
    case invalidFolder
    case isoMountFailed

    public var errorDescription: String? {
        switch self {
        case .noSupportedFiles:
            return "No supported image/video files were found"
        case .invalidFolder:
            return "Selected folder is invalid"
        case .isoMountFailed:
            return "Failed to mount ISO file"
        }
    }
}

@Observable
@MainActor
public final class ContentUploadCenterViewModel {
    public private(set) var sessions: [String: ContentUploadSession] = [:]
    public private(set) var completionTrigger = UUID()
    public private(set) var lastCompletedItemId: String?

    private let logger = Logger(label: "ContentUploadCenterViewModel")
    private let uploadService: ContentPreviewUploadServiceProtocol
    private let preprocessor: ContentUploadPreprocessorProtocol
    private var runTasks: [String: Task<Void, Never>] = [:]
    private var runIdentifiers: [String: UUID] = [:]
    #if os(macOS)
        private var isoMountPoints: [String: String] = [:]
    #endif

    private let maxConcurrency: Int
    private let maxAttempts: Int
    private let retryDelayNanoseconds: UInt64

    public init(
        uploadService: ContentPreviewUploadServiceProtocol = ContentPreviewUploadService(),
        preprocessor: ContentUploadPreprocessorProtocol = FFmpegContentUploadPreprocessor(),
        maxConcurrency: Int = 4,
        maxAttempts: Int = 3,
        retryDelayNanoseconds: UInt64 = 10_000_000_000
    ) {
        self.uploadService = uploadService
        self.preprocessor = preprocessor
        self.maxConcurrency = max(1, maxConcurrency)
        self.maxAttempts = max(1, maxAttempts)
        self.retryDelayNanoseconds = retryDelayNanoseconds
    }

    public func session(for itemId: String) -> ContentUploadSession? {
        sessions[itemId]
    }

    public func hasSession(for itemId: String) -> Bool {
        sessions[itemId] != nil
    }

    public func hasActiveSession(for itemId: String) -> Bool {
        guard let session = sessions[itemId] else { return false }
        return session.status == .running || session.status == .paused || session.status == .idle
    }

    public func isUploading(for itemId: String) -> Bool {
        guard let session = sessions[itemId] else { return false }
        return session.status == .running || session.status == .paused
    }

    public func removeSession(for itemId: String) {
        runTasks[itemId]?.cancel()
        runTasks[itemId] = nil
        runIdentifiers[itemId] = nil
        sessions[itemId] = nil
        #if os(macOS)
            if let mountPoint = isoMountPoints.removeValue(forKey: itemId) {
                Task {
                    await ISOService.unmount(mountPoint: mountPoint)
                }
            }
        #endif
    }

    @discardableResult
    public func createSessionFromFiles(
        itemId: String,
        itemTitle: String,
        fileURLs: [URL]
    ) throws -> ContentUploadSession {
        let files = try buildInputFiles(from: fileURLs, baseFolder: nil, extensionFilter: nil)
        return createSession(itemId: itemId, itemTitle: itemTitle, files: files)
    }

    @discardableResult
    public func createSessionFromFolder(
        itemId: String,
        itemTitle: String,
        folderURL: URL,
        extensionInput: String
    ) throws -> ContentUploadSession {
        let extensionFilter = ContentUploadCatalog.parseExtensionList(extensionInput)
        let files = try buildInputFiles(fromFolder: folderURL, extensionFilter: extensionFilter)
        return createSession(itemId: itemId, itemTitle: itemTitle, files: files)
    }

    #if os(macOS)
        @discardableResult
        public func createSessionFromISO(
            itemId: String,
            itemTitle: String,
            isoURL: URL,
            extensionInput: String
        ) async throws -> ContentUploadSession {
            guard let mountPoint = await ISOService.mount(isoPath: isoURL.path) else {
                throw ContentUploadCenterError.isoMountFailed
            }
            let folderURL = URL(fileURLWithPath: mountPoint)
            let extensionFilter = ContentUploadCatalog.parseExtensionList(extensionInput)
            do {
                let files = try buildInputFiles(fromFolder: folderURL, extensionFilter: extensionFilter)
                let session = createSession(itemId: itemId, itemTitle: itemTitle, files: files)
                isoMountPoints[itemId] = mountPoint
                return session
            } catch {
                await ISOService.unmount(mountPoint: mountPoint)
                throw error
            }
        }
    #endif

    public func beginUpload(itemId: String, mode: ContentUploadVideoMode) {
        guard var session = sessions[itemId] else { return }
        guard session.status != .running else { return }
        guard session.status != .stopped else { return }

        for index in session.files.indices {
            switch session.files[index].status {
            case .cancelled:
                session.files[index].status = .pending
                session.files[index].progress = 0
                session.files[index].errorMessage = nil
                session.files[index].logMessage = nil
                session.files[index].finishedAt = nil
            default:
                break
            }
        }

        session.status = .running
        session.videoMode = mode
        session.lastErrorMessage = nil
        if session.startedAt == nil {
            session.startedAt = Date()
        }
        sessions[itemId] = session

        let runID = UUID()
        runIdentifiers[itemId] = runID
        startRunTask(itemId: itemId, runID: runID)
    }

    public func pauseUpload(itemId: String) {
        guard var session = sessions[itemId], session.status == .running else { return }
        session.status = .paused
        markInProgressFilesCancelled(&session)
        sessions[itemId] = session
        runTasks[itemId]?.cancel()
        runTasks[itemId] = nil
        runIdentifiers[itemId] = nil
    }

    public func stopUploadCompletely(itemId: String) {
        guard var session = sessions[itemId] else { return }
        guard session.status != .stopped else { return }

        session.status = .stopped
        session.finishedAt = Date()
        markUnfinishedFilesCancelled(&session)
        sessions[itemId] = session

        runTasks[itemId]?.cancel()
        runTasks[itemId] = nil
        runIdentifiers[itemId] = nil

        notifyCompletionIfNeeded(itemId: itemId, session: session)
    }

    private func createSession(itemId: String, itemTitle: String, files: [ContentUploadInputFile]) -> ContentUploadSession {
        runTasks[itemId]?.cancel()
        runTasks[itemId] = nil
        runIdentifiers[itemId] = nil

        let progressFiles = files.map { ContentUploadFileProgress(inputFile: $0) }
        let session = ContentUploadSession(itemId: itemId, itemTitle: itemTitle, files: progressFiles)
        sessions[itemId] = session
        return session
    }

    private func startRunTask(itemId: String, runID: UUID) {
        runTasks[itemId]?.cancel()
        runTasks[itemId] = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            guard await self.isCurrentRun(itemId: itemId, runID: runID) else { return }

            let fileIDs = await self.pendingOrCancelledFileIDs(itemId: itemId)
            guard !fileIDs.isEmpty else {
                await self.completeSessionIfNeeded(itemId: itemId, runID: runID)
                return
            }

            await withTaskGroup(of: Void.self) { group in
                var iterator = fileIDs.makeIterator()

                for _ in 0 ..< self.maxConcurrency {
                    guard let nextId = iterator.next() else { break }
                    group.addTask { [weak self] in
                        guard let self else { return }
                        await self.processFile(itemId: itemId, fileId: nextId, runID: runID)
                    }
                }

                while await group.next() != nil {
                    if Task.isCancelled {
                        break
                    }
                    guard let nextId = iterator.next() else { continue }
                    group.addTask { [weak self] in
                        guard let self else { return }
                        await self.processFile(itemId: itemId, fileId: nextId, runID: runID)
                    }
                }
            }

            await self.finalizeRun(itemId: itemId, runID: runID)
        }
    }

    private func processFile(itemId: String, fileId: UUID, runID: UUID) async {
        guard isCurrentRun(itemId: itemId, runID: runID) else { return }
        guard let (file, mode) = fileAndMode(itemId: itemId, fileId: fileId) else { return }

        do {
            updateFileIfCurrent(itemId: itemId, fileId: fileId, runID: runID, status: .preprocessing, progress: 0.05)

            let tempFolder = temporaryDirectory(itemId: itemId, fileId: fileId)
            let preparedAsset = try await preprocessor.prepareFile(
                file: file,
                mode: mode,
                temporaryDirectory: tempFolder
            )

            for attempt in 1 ... maxAttempts {
                if Task.isCancelled {
                    updateFileIfCurrent(itemId: itemId, fileId: fileId, runID: runID, status: .cancelled, progress: 0)
                    return
                }
                guard isCurrentRun(itemId: itemId, runID: runID) else { return }

                do {
                    updateFileIfCurrent(itemId: itemId, fileId: fileId, runID: runID, status: .requestingUploadURL(attempt: attempt), progress: 0.2, attemptsUsed: attempt)

                    let requestItem = ContentPreviewUploadRequestItem(
                        filename: file.filename,
                        mediaType: file.mediaType,
                        title: file.filename,
                        mimeType: file.mimeType,
                        size: Int(file.fileSize),
                        filePath: file.relativePath,
                        videoLength: file.mediaType == .video ? preparedAsset.videoLength.map { max($0, 0) } : nil
                    )

                    let targets = try await uploadService.getUploadTargets(itemId: itemId, items: [requestItem])
                    guard let target = targets.first else {
                        throw ContentPreviewUploadServiceError.serverError("No upload URL returned")
                    }

                    updateFileIfCurrent(itemId: itemId, fileId: fileId, runID: runID, status: .uploadingThumbnail(attempt: attempt), progress: 0.55, attemptsUsed: attempt)

                    try await uploadService.uploadToPresignedURL(
                        uploadURL: target.imageURL,
                        fileURL: preparedAsset.thumbnailURL,
                        contentType: "image/jpeg",
                        onProgress: { [weak self] uploaded, total in
                            Task { @MainActor in
                                guard let self else { return }
                                let fraction = total > 0 ? Double(uploaded) / Double(total) : 0
                                self.updateFileProgressPortionIfCurrent(
                                    itemId: itemId,
                                    fileId: fileId,
                                    runID: runID,
                                    base: 0.55,
                                    span: preparedAsset.uploadVideoURL == nil ? 0.45 : 0.25,
                                    fraction: fraction
                                )
                            }
                        }
                    )

                    if let uploadVideoURL = preparedAsset.uploadVideoURL,
                       let videoTargetURL = target.videoURL
                    {
                        updateFileIfCurrent(itemId: itemId, fileId: fileId, runID: runID, status: .uploadingVideo(attempt: attempt), progress: 0.8, attemptsUsed: attempt)

                        try await uploadService.uploadToPresignedURL(
                            uploadURL: videoTargetURL,
                            fileURL: uploadVideoURL,
                            contentType: file.mimeType,
                            onProgress: { [weak self] uploaded, total in
                                Task { @MainActor in
                                    guard let self else { return }
                                    let fraction = total > 0 ? Double(uploaded) / Double(total) : 0
                                    self.updateFileProgressPortionIfCurrent(
                                        itemId: itemId,
                                        fileId: fileId,
                                        runID: runID,
                                        base: 0.8,
                                        span: 0.2,
                                        fraction: fraction
                                    )
                                }
                            }
                        )
                    }

                    updateFileIfCurrent(itemId: itemId, fileId: fileId, runID: runID, status: .succeeded, progress: 1, attemptsUsed: attempt)
                    return
                } catch is CancellationError {
                    updateFileIfCurrent(itemId: itemId, fileId: fileId, runID: runID, status: .cancelled, progress: 0)
                    return
                } catch {
                    let message = error.localizedDescription
                    let logMessage = self.logMessage(from: error)
                    logger.warning("Upload attempt failed", metadata: ["itemId": "\(itemId)", "file": "\(file.filename)", "attempt": "\(attempt)", "error": "\(message)"])

                    if attempt < maxAttempts {
                        if retryDelayNanoseconds > 0 {
                            try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
                        }
                    } else {
                        updateFileIfCurrent(
                            itemId: itemId,
                            fileId: fileId,
                            runID: runID,
                            status: .failed(message),
                            progress: 1,
                            attemptsUsed: attempt,
                            errorMessage: message,
                            logMessage: logMessage
                        )
                        return
                    }
                }
            }
        } catch is CancellationError {
            updateFileIfCurrent(itemId: itemId, fileId: fileId, runID: runID, status: .cancelled, progress: 0)
        } catch {
            let message = error.localizedDescription
            updateFileIfCurrent(
                itemId: itemId,
                fileId: fileId,
                runID: runID,
                status: .failed(message),
                progress: 1,
                attemptsUsed: 1,
                errorMessage: message,
                logMessage: logMessage(from: error)
            )
        }
    }

    private func finalizeRun(itemId: String, runID: UUID) {
        guard isCurrentRun(itemId: itemId, runID: runID) else { return }
        runTasks[itemId] = nil
        runIdentifiers[itemId] = nil
        guard var session = sessions[itemId] else { return }

        switch session.status {
        case .paused, .stopped, .completed:
            sessions[itemId] = session
            return
        case .idle:
            sessions[itemId] = session
            return
        case .running:
            if session.files.allSatisfy({ $0.status.isFinished }) {
                session.status = .completed
                session.finishedAt = Date()
            } else {
                session.status = .paused
            }
            sessions[itemId] = session
            notifyCompletionIfNeeded(itemId: itemId, session: session)
        }
    }

    private func completeSessionIfNeeded(itemId: String, runID: UUID) {
        guard isCurrentRun(itemId: itemId, runID: runID) else { return }
        guard var session = sessions[itemId], session.status == .running else { return }
        if session.files.allSatisfy({ $0.status.isFinished }) {
            session.status = .completed
            session.finishedAt = Date()
            sessions[itemId] = session
            runTasks[itemId] = nil
            runIdentifiers[itemId] = nil
            notifyCompletionIfNeeded(itemId: itemId, session: session)
        }
    }

    private func isCurrentRun(itemId: String, runID: UUID) -> Bool {
        runIdentifiers[itemId] == runID
    }

    private func notifyCompletionIfNeeded(itemId: String, session: ContentUploadSession) {
        guard session.succeededCount > 0 else { return }
        lastCompletedItemId = itemId
        completionTrigger = UUID()
    }

    private func fileAndMode(itemId: String, fileId: UUID) -> (ContentUploadInputFile, ContentUploadVideoMode)? {
        guard let session = sessions[itemId], let mode = session.videoMode,
              let file = session.files.first(where: { $0.id == fileId })?.inputFile
        else {
            return nil
        }
        return (file, mode)
    }

    private func pendingOrCancelledFileIDs(itemId: String) -> [UUID] {
        guard let session = sessions[itemId] else { return [] }
        return session.files.compactMap { file in
            switch file.status {
            case .pending, .cancelled:
                return file.id
            default:
                return nil
            }
        }
    }

    private func updateFile(
        itemId: String,
        fileId: UUID,
        status: ContentUploadFileStatus,
        progress: Double,
        attemptsUsed: Int? = nil,
        errorMessage: String? = nil,
        logMessage: String? = nil
    ) {
        guard var session = sessions[itemId],
              let index = session.files.firstIndex(where: { $0.id == fileId })
        else {
            return
        }

        session.files[index].status = status
        session.files[index].progress = max(0, min(progress, 1))
        if let attemptsUsed {
            session.files[index].attemptsUsed = attemptsUsed
        }
        if session.files[index].startedAt == nil {
            session.files[index].startedAt = Date()
        }
        switch status {
        case .succeeded, .failed, .cancelled:
            session.files[index].finishedAt = Date()
        default:
            break
        }
        if let errorMessage {
            session.files[index].errorMessage = errorMessage
        }
        if let logMessage {
            session.files[index].logMessage = logMessage
        }

        sessions[itemId] = session
    }

    private func updateFileIfCurrent(
        itemId: String,
        fileId: UUID,
        runID: UUID,
        status: ContentUploadFileStatus,
        progress: Double,
        attemptsUsed: Int? = nil,
        errorMessage: String? = nil,
        logMessage: String? = nil
    ) {
        guard isCurrentRun(itemId: itemId, runID: runID) else { return }
        updateFile(
            itemId: itemId,
            fileId: fileId,
            status: status,
            progress: progress,
            attemptsUsed: attemptsUsed,
            errorMessage: errorMessage,
            logMessage: logMessage
        )
    }

    private func updateFileProgressPortion(
        itemId: String,
        fileId: UUID,
        base: Double,
        span: Double,
        fraction: Double
    ) {
        guard var session = sessions[itemId],
              let index = session.files.firstIndex(where: { $0.id == fileId })
        else {
            return
        }
        let normalized = max(0, min(fraction, 1))
        session.files[index].progress = min(1, base + span * normalized)
        sessions[itemId] = session
    }

    private func updateFileProgressPortionIfCurrent(
        itemId: String,
        fileId: UUID,
        runID: UUID,
        base: Double,
        span: Double,
        fraction: Double
    ) {
        guard isCurrentRun(itemId: itemId, runID: runID) else { return }
        updateFileProgressPortion(
            itemId: itemId,
            fileId: fileId,
            base: base,
            span: span,
            fraction: fraction
        )
    }

    private func markInProgressFilesCancelled(_ session: inout ContentUploadSession) {
        for index in session.files.indices where session.files[index].status.isInProgress {
            session.files[index].status = .cancelled
            session.files[index].finishedAt = Date()
            session.files[index].errorMessage = "Paused"
            session.files[index].logMessage = nil
        }
    }

    private func markUnfinishedFilesCancelled(_ session: inout ContentUploadSession) {
        for index in session.files.indices where !session.files[index].status.isFinished {
            session.files[index].status = .cancelled
            session.files[index].finishedAt = Date()
            session.files[index].errorMessage = "Stopped"
            session.files[index].logMessage = nil
        }
    }

    private func logMessage(from error: Error) -> String? {
        if let preprocessError = error as? ContentUploadPreprocessError {
            return preprocessError.logMessage
        }
        return nil
    }

    private func temporaryDirectory(itemId: String, fileId: UUID) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("rxstorage-content-upload", isDirectory: true)
            .appendingPathComponent(itemId, isDirectory: true)
            .appendingPathComponent(fileId.uuidString, isDirectory: true)
    }

    private func buildInputFiles(
        from urls: [URL],
        baseFolder: URL?,
        extensionFilter: Set<String>?
    ) throws -> [ContentUploadInputFile] {
        let fm = FileManager.default
        let files: [ContentUploadInputFile] = urls.compactMap { url in
            let ext = url.pathExtension.lowercased()
            guard let mediaType = ContentUploadCatalog.mediaType(forExtension: ext) else {
                return nil
            }
            if let extensionFilter, !extensionFilter.isEmpty, !extensionFilter.contains(ext) {
                return nil
            }

            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else {
                return nil
            }
            let attrs = try? fm.attributesOfItem(atPath: url.path)
            let size = attrs?[.size] as? NSNumber

            let relativePath: String
            if let baseFolder {
                let folderPath = baseFolder.standardizedFileURL.path + "/"
                let filePath = url.standardizedFileURL.path
                if filePath.hasPrefix(folderPath) {
                    relativePath = String(filePath.dropFirst(folderPath.count))
                } else {
                    relativePath = url.lastPathComponent
                }
            } else {
                relativePath = url.lastPathComponent
            }

            return ContentUploadInputFile(
                fileURL: url,
                filename: url.lastPathComponent,
                relativePath: relativePath,
                extensionName: ext,
                mimeType: ContentUploadCatalog.mimeType(forExtension: ext),
                mediaType: mediaType,
                fileSize: size?.int64Value ?? 0
            )
        }

        let sorted = files.sorted { $0.relativePath.localizedCaseInsensitiveCompare($1.relativePath) == .orderedAscending }
        guard !sorted.isEmpty else {
            throw ContentUploadCenterError.noSupportedFiles
        }
        return sorted
    }

    private func buildInputFiles(fromFolder folderURL: URL, extensionFilter: Set<String>) throws -> [ContentUploadInputFile] {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isDir), isDir.boolValue else {
            throw ContentUploadCenterError.invalidFolder
        }

        let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )

        var urls: [URL] = []
        while let next = enumerator?.nextObject() as? URL {
            urls.append(next)
        }

        return try buildInputFiles(from: urls, baseFolder: folderURL, extensionFilter: extensionFilter)
    }
}

// MARK: - Preview Helpers

#if DEBUG
    public extension ContentUploadCenterViewModel {
        static func previewRunning() -> ContentUploadCenterViewModel {
            let vm = ContentUploadCenterViewModel()
            let files = previewFiles()
            var progressFiles = files.map { ContentUploadFileProgress(inputFile: $0) }

            // First file: succeeded
            progressFiles[0].status = .succeeded
            progressFiles[0].progress = 1.0

            // Second file: uploading
            progressFiles[1].status = .uploadingThumbnail(attempt: 1)
            progressFiles[1].progress = 0.65
            progressFiles[1].attemptsUsed = 1

            // Third file: pending
            progressFiles[2].status = .pending
            progressFiles[2].progress = 0

            // Fourth file: failed
            progressFiles[3].status = .failed("Network connection lost")
            progressFiles[3].progress = 1.0
            progressFiles[3].attemptsUsed = 3
            progressFiles[3].errorMessage = "Network connection lost"
            progressFiles[3].logMessage = "Error: Connection timed out after 30 seconds\nRetry 1: Failed\nRetry 2: Failed\nRetry 3: Failed"

            let session = ContentUploadSession(
                itemId: "preview-item",
                itemTitle: "Sample Item",
                status: .running,
                videoMode: .videoAndImage,
                files: progressFiles,
                startedAt: Date()
            )
            vm.sessions["preview-item"] = session
            return vm
        }

        static func previewCompleted() -> ContentUploadCenterViewModel {
            let vm = ContentUploadCenterViewModel()
            let files = previewFiles()
            var progressFiles = files.map { ContentUploadFileProgress(inputFile: $0) }

            for i in progressFiles.indices {
                progressFiles[i].status = .succeeded
                progressFiles[i].progress = 1.0
            }

            let session = ContentUploadSession(
                itemId: "preview-item",
                itemTitle: "Sample Item",
                status: .completed,
                videoMode: .imageOnly,
                files: progressFiles,
                startedAt: Date().addingTimeInterval(-120),
                finishedAt: Date()
            )
            vm.sessions["preview-item"] = session
            return vm
        }

        static func previewIdle() -> ContentUploadCenterViewModel {
            let vm = ContentUploadCenterViewModel()
            let files = previewFiles()
            let progressFiles = files.map { ContentUploadFileProgress(inputFile: $0) }

            let session = ContentUploadSession(
                itemId: "preview-item",
                itemTitle: "Sample Item",
                status: .idle,
                files: progressFiles
            )
            vm.sessions["preview-item"] = session
            return vm
        }

        private static func previewFiles() -> [ContentUploadInputFile] {
            [
                ContentUploadInputFile(
                    fileURL: URL(fileURLWithPath: "/tmp/photo1.jpg"),
                    filename: "photo1.jpg",
                    relativePath: "photo1.jpg",
                    extensionName: "jpg",
                    mimeType: "image/jpeg",
                    mediaType: .image,
                    fileSize: 2_456_789
                ),
                ContentUploadInputFile(
                    fileURL: URL(fileURLWithPath: "/tmp/video.mp4"),
                    filename: "vacation_video.mp4",
                    relativePath: "Videos/vacation_video.mp4",
                    extensionName: "mp4",
                    mimeType: "video/mp4",
                    mediaType: .video,
                    fileSize: 156_789_012
                ),
                ContentUploadInputFile(
                    fileURL: URL(fileURLWithPath: "/tmp/photo2.png"),
                    filename: "screenshot.png",
                    relativePath: "Screenshots/screenshot.png",
                    extensionName: "png",
                    mimeType: "image/png",
                    mediaType: .image,
                    fileSize: 1_234_567
                ),
                ContentUploadInputFile(
                    fileURL: URL(fileURLWithPath: "/tmp/photo3.heic"),
                    filename: "IMG_0042.heic",
                    relativePath: "Camera Roll/IMG_0042.heic",
                    extensionName: "heic",
                    mimeType: "image/heic",
                    mediaType: .image,
                    fileSize: 3_456_789
                ),
            ]
        }
    }
#endif
