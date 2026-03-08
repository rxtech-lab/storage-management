import Foundation

extension UploadContentView {
    func scanFiles() {
        let extList = extensions.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        guard !extList.isEmpty else {
            errorMessage = "No extensions provided"
            return
        }

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: directoryPath) else {
            errorMessage = "Cannot read directory"
            return
        }

        var files: [FileEntry] = []
        while let file = enumerator.nextObject() as? String {
            let ext = (file as NSString).pathExtension.lowercased()
            if extList.contains(ext) {
                let fullPath = (directoryPath as NSString).appendingPathComponent(file)
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: fullPath, isDirectory: &isDir), !isDir.boolValue {
                    let mimeType = FFmpegService.mimeTypeForExtension(ext)
                    let fileType: FileEntry.FileType = mimeType.hasPrefix("video/") ? .video : .image
                    let attrs = try? fm.attributesOfItem(atPath: fullPath)
                    let size = (attrs?[.size] as? Int) ?? 0
                    files.append(FileEntry(
                        path: fullPath,
                        filename: (file as NSString).lastPathComponent,
                        ext: ext,
                        mimeType: mimeType,
                        type: fileType,
                        size: size
                    ))
                }
            }
        }

        matchedFiles = files.sorted { $0.filename < $1.filename }
        step = .listFiles
    }

    func startUpload() {
        step = .uploading
        uploadTotal = matchedFiles.count
        uploadProgress = 0
        errorMessage = nil
        uploadResults = []

        Task {
            await performUpload()
        }
    }

    private func performUpload() async {
        var results: [UploadResult] = []

        let tempDir = NSTemporaryDirectory() + "rxstorage-previews-\(UUID().uuidString)/"
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let maxConcurrency = 4
        AppLogger.upload.info("Starting upload for \(matchedFiles.count) file(s), \(maxConcurrency) parallel jobs, tempDir: \(tempDir)")

        let files = matchedFiles
        let total = files.count
        let itemIdCopy = itemId
        let uploadMode = videoUploadMode

        await withTaskGroup(of: UploadResult.self) { group in
            var iterator = files.enumerated().makeIterator()

            // Seed initial batch
            for _ in 0..<maxConcurrency {
                guard let (index, file) = iterator.next() else { break }
                group.addTask {
                    await Self.processAndUploadFile(
                        file, index: index, total: total, tempDir: tempDir,
                        itemId: itemIdCopy, videoUploadMode: uploadMode
                    )
                }
            }

            // As each completes, start next
            for await result in group {
                results.append(result)
                await updateProgress(results: results)
                if let (index, file) = iterator.next() {
                    group.addTask {
                        await Self.processAndUploadFile(
                            file, index: index, total: total, tempDir: tempDir,
                            itemId: itemIdCopy, videoUploadMode: uploadMode
                        )
                    }
                }
            }
        }

        AppLogger.upload.info("Upload complete. \(results.filter { $0.success }.count)/\(results.count) succeeded")
        uploadResults = results
        cleanupISO()
        step = .done
    }

    private static func processAndUploadFile(
        _ file: FileEntry, index: Int, total: Int, tempDir: String,
        itemId: String, videoUploadMode: VideoUploadMode
    ) async -> UploadResult {
        // Per-file subdirectory to avoid collisions between parallel jobs
        let fileDir = tempDir + "\(index)/"
        try? FileManager.default.createDirectory(atPath: fileDir, withIntermediateDirectories: true)

        let thumbPath = fileDir + "\(file.filename).thumb.jpg"
        var videoPath: String? = nil
        var videoLength: Double? = nil

        // Step 1: Compress / generate preview with ffmpeg
        if file.type == .video {
            AppLogger.upload.info("[\(index+1)/\(total)] Processing video: \(file.filename) (\(file.size) bytes)")
            videoLength = FFmpegService.getVideoDuration(file.path)
            AppLogger.upload.info("Video duration: \(videoLength.map { String($0) } ?? "nil")")

            let success = FFmpegService.generateVideoThumbnail(inputPath: file.path, outputPath: thumbPath)
            AppLogger.upload.info("Video thumbnail result: \(success)")
            if !success {
                return UploadResult(filename: file.filename, success: false, error: "ffmpeg thumbnail failed")
            }
            if videoUploadMode == .videoAndImage {
                let compressedPath = fileDir + "\(file.filename).compressed.mp4"
                AppLogger.upload.info("Compressing video -> \(compressedPath)")
                let compressSuccess = FFmpegService.compressVideo(inputPath: file.path, outputPath: compressedPath)
                AppLogger.upload.info("Video compression result: \(compressSuccess)")
                videoPath = compressSuccess ? compressedPath : file.path
            }
        } else {
            AppLogger.upload.info("[\(index+1)/\(total)] Processing image: \(file.filename) (\(file.size) bytes)")
            let success = FFmpegService.generateImagePreview(inputPath: file.path, outputPath: thumbPath)
            AppLogger.upload.info("Image preview result: \(success)")
            if !success {
                AppLogger.upload.info("Falling back to file copy for: \(file.filename)")
                try? FileManager.default.copyItem(atPath: file.path, toPath: thumbPath)
            }
        }

        // Step 2: Upload with retry (3 attempts, 10s delay)
        let uploadItem = ContentPreviewUploadItem(
            filename: file.filename,
            type: file.type == .video ? .video : .image,
            title: file.filename,
            mimeType: file.mimeType,
            size: file.size,
            filePath: file.path,
            videoLength: videoLength
        )

        var lastError: String? = nil

        for attempt in 1...3 {
            do {
                AppLogger.upload.info("[\(index+1)/\(total)] Requesting presigned URL for: \(file.filename) (attempt \(attempt)/3)")
                let presignedResults = try await APIService.getContentPreviewUploadUrls(itemId: itemId, items: [uploadItem])
                guard let presigned = presignedResults.first else {
                    lastError = "No presigned URL returned"
                    AppLogger.upload.warning("No presigned URL returned for \(file.filename) (attempt \(attempt)/3)")
                    if attempt < 3 {
                        try? await Task.sleep(nanoseconds: 10_000_000_000)
                    }
                    continue
                }

                // Step 3: Upload thumbnail
                AppLogger.upload.info("[\(index+1)/\(total)] Uploading thumbnail for: \(file.filename)")
                let thumbData = try Data(contentsOf: URL(fileURLWithPath: thumbPath))
                try await APIService.uploadToPresignedUrl(
                    url: presigned.imageUrl,
                    data: thumbData,
                    contentType: "image/jpeg"
                )
                AppLogger.upload.info("Thumbnail upload success for: \(file.filename)")

                // Step 4: Upload video if applicable
                if let vPath = videoPath, let videoUrl = presigned.videoUrl {
                    AppLogger.upload.info("[\(index+1)/\(total)] Uploading video for: \(file.filename)")
                    let videoData = try Data(contentsOf: URL(fileURLWithPath: vPath))
                    try await APIService.uploadToPresignedUrl(
                        url: videoUrl,
                        data: videoData,
                        contentType: file.mimeType
                    )
                    AppLogger.upload.info("Video upload success for: \(file.filename)")
                }

                return UploadResult(filename: file.filename, success: true, error: nil)
            } catch {
                lastError = error.localizedDescription
                AppLogger.upload.warning("Upload attempt \(attempt)/3 failed for \(file.filename): \(error)")
                if attempt < 3 {
                    try? await Task.sleep(nanoseconds: 10_000_000_000)
                }
            }
        }

        AppLogger.upload.error("Upload failed for \(file.filename) after 3 attempts: \(lastError ?? "unknown")")
        return UploadResult(filename: file.filename, success: false, error: lastError)
    }

    func updateProgress(results: [UploadResult]) async {
        uploadProgress = results.count
        uploadResults = results
    }

    func cleanupISO() {
        if let mountPoint = isoMountPoint {
            ISOService.unmount(mountPoint: mountPoint)
            isoMountPoint = nil
        }
    }
}
