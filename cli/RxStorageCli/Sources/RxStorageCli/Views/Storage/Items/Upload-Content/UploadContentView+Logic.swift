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

        AppLogger.upload.info("Starting upload for \(matchedFiles.count) file(s), tempDir: \(tempDir)")

        for (index, file) in matchedFiles.enumerated() {
            let thumbPath = tempDir + "\(file.filename).thumb.jpg"
            var videoPath: String? = nil
            var videoLength: Double? = nil

            // Step 1: Compress / generate preview with ffmpeg
            if file.type == .video {
                AppLogger.upload.info("[\(index+1)/\(matchedFiles.count)] Processing video: \(file.filename) (\(file.size) bytes)")
                videoLength = FFmpegService.getVideoDuration(file.path)
                AppLogger.upload.info("Video duration: \(videoLength.map { String($0) } ?? "nil")")

                let success = FFmpegService.generateVideoThumbnail(inputPath: file.path, outputPath: thumbPath)
                AppLogger.upload.info("Video thumbnail result: \(success)")
                if !success {
                    results.append(UploadResult(filename: file.filename, success: false, error: "ffmpeg thumbnail failed"))
                    await updateProgress(results: results)
                    continue
                }
                if videoUploadMode == .videoAndImage {
                    let compressedPath = tempDir + "\(file.filename).compressed.mp4"
                    AppLogger.upload.info("Compressing video -> \(compressedPath)")
                    let compressSuccess = FFmpegService.compressVideo(inputPath: file.path, outputPath: compressedPath)
                    AppLogger.upload.info("Video compression result: \(compressSuccess)")
                    videoPath = compressSuccess ? compressedPath : file.path
                }
            } else {
                AppLogger.upload.info("[\(index+1)/\(matchedFiles.count)] Processing image: \(file.filename) (\(file.size) bytes)")
                let success = FFmpegService.generateImagePreview(inputPath: file.path, outputPath: thumbPath)
                AppLogger.upload.info("Image preview result: \(success)")
                if !success {
                    AppLogger.upload.info("Falling back to file copy for: \(file.filename)")
                    try? FileManager.default.copyItem(atPath: file.path, toPath: thumbPath)
                }
            }

            // Step 2: Get presigned URL for this single file
            let uploadItem = ContentPreviewUploadItem(
                filename: file.filename,
                type: file.type == .video ? .video : .image,
                title: file.filename,
                mimeType: file.mimeType,
                size: file.size,
                filePath: file.path,
                videoLength: videoLength
            )

            do {
                AppLogger.upload.info("[\(index+1)/\(matchedFiles.count)] Requesting presigned URL for: \(file.filename)")
                let presignedResults = try await APIService.getContentPreviewUploadUrls(itemId: itemId, items: [uploadItem])
                guard let presigned = presignedResults.first else {
                    results.append(UploadResult(filename: file.filename, success: false, error: "No presigned URL returned"))
                    await updateProgress(results: results)
                    continue
                }

                // Step 3: Upload thumbnail
                AppLogger.upload.info("[\(index+1)/\(matchedFiles.count)] Uploading thumbnail for: \(file.filename)")
                let thumbData = try Data(contentsOf: URL(fileURLWithPath: thumbPath))
                AppLogger.upload.info("Thumbnail size: \(thumbData.count) bytes")
                try await APIService.uploadToPresignedUrl(
                    url: presigned.imageUrl,
                    data: thumbData,
                    contentType: "image/jpeg"
                )
                AppLogger.upload.info("Thumbnail upload success for: \(file.filename)")

                // Step 4: Upload video if applicable
                if let vPath = videoPath, let videoUrl = presigned.videoUrl {
                    AppLogger.upload.info("[\(index+1)/\(matchedFiles.count)] Uploading video for: \(file.filename)")
                    let videoData = try Data(contentsOf: URL(fileURLWithPath: vPath))
                    AppLogger.upload.info("Video size: \(videoData.count) bytes")
                    try await APIService.uploadToPresignedUrl(
                        url: videoUrl,
                        data: videoData,
                        contentType: file.mimeType
                    )
                    AppLogger.upload.info("Video upload success for: \(file.filename)")
                }

                results.append(UploadResult(filename: file.filename, success: true, error: nil))
            } catch {
                AppLogger.upload.error("Upload failed for \(file.filename): \(error)")
                results.append(UploadResult(filename: file.filename, success: false, error: error.localizedDescription))
            }

            await updateProgress(results: results)
        }

        AppLogger.upload.info("Upload complete. \(results.filter { $0.success }.count)/\(results.count) succeeded")
        uploadResults = results
        step = .done
    }

    func updateProgress(results: [UploadResult]) async {
        uploadProgress = results.count
        uploadResults = results
    }
}
