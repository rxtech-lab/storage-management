import Foundation
@testable import RxStorageCore
import Testing

@Suite("ContentUploadCenterViewModel")
struct ContentUploadCenterViewModelTests {
    @Test("pause then resume processes remaining files")
    @MainActor
    func pauseAndResume() async throws {
        let uploadService = MockContentPreviewUploadService()
        let preprocessor = MockContentUploadPreprocessor(preprocessDelayNanoseconds: 150_000_000)
        let viewModel = ContentUploadCenterViewModel(
            uploadService: uploadService,
            preprocessor: preprocessor,
            maxConcurrency: 1,
            maxAttempts: 1,
            retryDelayNanoseconds: 0
        )

        let fileURLs = try makeTempFiles(names: ["a.jpg", "b.jpg", "c.jpg"])
        _ = try viewModel.createSessionFromFiles(itemId: "item-1", itemTitle: "Item 1", fileURLs: fileURLs)

        viewModel.beginUpload(itemId: "item-1", mode: .imageOnly)
        try await Task.sleep(nanoseconds: 220_000_000)
        viewModel.pauseUpload(itemId: "item-1")

        let pausedSession = viewModel.session(for: "item-1")
        #expect(pausedSession?.status == .paused)

        viewModel.beginUpload(itemId: "item-1", mode: .imageOnly)
        try await waitUntil(timeoutNanoseconds: 5_000_000_000) {
            viewModel.session(for: "item-1")?.status == .completed
        }

        let completed = viewModel.session(for: "item-1")
        #expect(completed?.succeededCount == 3)
        #expect(completed?.failedCount == 0)
    }

    @Test("stop completely keeps partial results and marks session stopped")
    @MainActor
    func stopCompletely() async throws {
        let uploadService = MockContentPreviewUploadService(uploadDelayNanoseconds: 220_000_000)
        let preprocessor = MockContentUploadPreprocessor(preprocessDelayNanoseconds: 120_000_000)
        let viewModel = ContentUploadCenterViewModel(
            uploadService: uploadService,
            preprocessor: preprocessor,
            maxConcurrency: 1,
            maxAttempts: 1,
            retryDelayNanoseconds: 0
        )

        let fileURLs = try makeTempFiles(names: ["s1.jpg", "s2.jpg", "s3.jpg"])
        _ = try viewModel.createSessionFromFiles(itemId: "item-stop", itemTitle: "Item Stop", fileURLs: fileURLs)

        viewModel.beginUpload(itemId: "item-stop", mode: .imageOnly)
        try await Task.sleep(nanoseconds: 260_000_000)
        viewModel.stopUploadCompletely(itemId: "item-stop")

        let stopped = viewModel.session(for: "item-stop")
        #expect(stopped?.status == .stopped)
        #expect(stopped?.completedCount == stopped?.totalCount)

        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(viewModel.session(for: "item-stop")?.status == .stopped)
    }

    @Test("resume processes cancelled files but does not retry failed files")
    @MainActor
    func resumeDoesNotRetryFailed() async throws {
        let uploadService = MockContentPreviewUploadService(
            uploadDelayNanoseconds: 160_000_000,
            alwaysFailFilenames: ["fail.jpg"]
        )
        let preprocessor = MockContentUploadPreprocessor(preprocessDelayNanoseconds: 50_000_000)
        let viewModel = ContentUploadCenterViewModel(
            uploadService: uploadService,
            preprocessor: preprocessor,
            maxConcurrency: 1,
            maxAttempts: 1,
            retryDelayNanoseconds: 0
        )

        let fileURLs = try makeTempFiles(names: ["fail.jpg", "ok1.jpg", "ok2.jpg"])
        _ = try viewModel.createSessionFromFiles(itemId: "item-resume", itemTitle: "Item Resume", fileURLs: fileURLs)

        viewModel.beginUpload(itemId: "item-resume", mode: .imageOnly)
        try await Task.sleep(nanoseconds: 330_000_000)
        viewModel.pauseUpload(itemId: "item-resume")

        viewModel.beginUpload(itemId: "item-resume", mode: .imageOnly)
        try await waitUntil(timeoutNanoseconds: 5_000_000_000) {
            viewModel.session(for: "item-resume")?.status == .completed
        }

        let failAttempts = await uploadService.requestCount(for: "fail.jpg")
        #expect(failAttempts == 1)

        let session = viewModel.session(for: "item-resume")
        let failedFile = session?.files.first(where: { $0.inputFile.filename == "fail.jpg" })
        #expect(failedFile != nil)
        if let failedFile {
            if case .failed = failedFile.status {
                // expected
            } else {
                Issue.record("Expected fail.jpg to remain failed")
            }
        }
    }

    @Test("content preview upload request mapping keeps video fields")
    func requestBodyMapping() {
        let body = ContentPreviewUploadService.makeRequestBody(
            itemId: "item-42",
            items: [
                ContentPreviewUploadRequestItem(
                    filename: "clip.mp4",
                    mediaType: .video,
                    title: "clip.mp4",
                    description: "demo",
                    mimeType: "video/mp4",
                    size: 1024,
                    filePath: "folder/clip.mp4",
                    videoLength: 12.5
                ),
            ]
        )

        #expect(body.item_id == "item-42")
        #expect(body.items.count == 1)
        #expect(body.items[0].filename == "clip.mp4")
        #expect(body.items[0]._type == .video)
        #expect(body.items[0].mime_type == "video/mp4")
        #expect(body.items[0].file_path == "folder/clip.mp4")
        #expect(body.items[0].video_length == 12.5)
    }
}

private actor MockContentPreviewUploadService: ContentPreviewUploadServiceProtocol {
    private var counts: [String: Int] = [:]
    private let uploadDelayNanoseconds: UInt64
    private let alwaysFailFilenames: Set<String>

    init(uploadDelayNanoseconds: UInt64 = 80_000_000, alwaysFailFilenames: Set<String> = []) {
        self.uploadDelayNanoseconds = uploadDelayNanoseconds
        self.alwaysFailFilenames = alwaysFailFilenames
    }

    func getUploadTargets(itemId _: String, items: [ContentPreviewUploadRequestItem]) async throws -> [ContentPreviewUploadTarget] {
        let item = items[0]
        counts[item.filename, default: 0] += 1

        if alwaysFailFilenames.contains(item.filename) {
            throw ContentPreviewUploadServiceError.serverError("forced failure")
        }

        return [
            ContentPreviewUploadTarget(
                id: UUID().uuidString,
                imageURL: "https://example.com/upload/\(item.filename)/thumb",
                videoURL: item.mediaType == .video ? "https://example.com/upload/\(item.filename)/video" : nil
            ),
        ]
    }

    func uploadToPresignedURL(
        uploadURL _: String,
        fileURL _: URL,
        contentType _: String,
        onProgress: UploadProgressHandler?
    ) async throws {
        onProgress?(0, 1)
        try await Task.sleep(nanoseconds: uploadDelayNanoseconds)
        onProgress?(1, 1)
    }

    func requestCount(for filename: String) -> Int {
        counts[filename, default: 0]
    }
}

private struct MockContentUploadPreprocessor: ContentUploadPreprocessorProtocol {
    let preprocessDelayNanoseconds: UInt64

    func prepareFile(
        file: ContentUploadInputFile,
        mode: ContentUploadVideoMode,
        temporaryDirectory: URL
    ) async throws -> ContentUploadPreparedAsset {
        try await Task.sleep(nanoseconds: preprocessDelayNanoseconds)
        let fm = FileManager.default
        try fm.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

        let thumb = temporaryDirectory.appendingPathComponent("thumb.jpg")
        try Data([0x01]).write(to: thumb)

        if mode == .videoAndImage, file.mediaType == .video {
            let video = temporaryDirectory.appendingPathComponent("compressed.mp4")
            try Data([0x02]).write(to: video)
            return ContentUploadPreparedAsset(thumbnailURL: thumb, uploadVideoURL: video, videoLength: 3)
        }

        return ContentUploadPreparedAsset(
            thumbnailURL: thumb,
            uploadVideoURL: mode == .videoAndImage && file.mediaType == .video ? file.fileURL : nil,
            videoLength: file.mediaType == .video ? 3 : nil
        )
    }
}

private func makeTempFiles(names: [String]) throws -> [URL] {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("content-upload-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    return try names.map { name in
        let url = dir.appendingPathComponent(name)
        try Data([0xFF, 0xD8, 0xFF]).write(to: url)
        return url
    }
}

@MainActor
private func waitUntil(
    timeoutNanoseconds: UInt64,
    intervalNanoseconds: UInt64 = 50_000_000,
    condition: @escaping () -> Bool
) async throws {
    let start = DispatchTime.now().uptimeNanoseconds
    while !condition() {
        try await Task.sleep(nanoseconds: intervalNanoseconds)
        let elapsed = DispatchTime.now().uptimeNanoseconds - start
        if elapsed > timeoutNanoseconds {
            Issue.record("Timed out waiting for condition")
            return
        }
    }
}
