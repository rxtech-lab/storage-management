import Foundation
import OpenAPIRuntime

extension UploadContentView {
    struct PreviewFile {
        let original: FileEntry
        let thumbnailPath: String
        let videoPath: String?
        let videoLength: Double?
    }

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

        AppLogger.info("Upload", "Starting upload for \(matchedFiles.count) file(s), tempDir: \(tempDir)")

        var previews: [PreviewFile] = []

        for file in matchedFiles {
            let thumbPath = tempDir + "\(file.filename).thumb.jpg"

            if file.type == .video {
                AppLogger.info("Upload", "Processing video: \(file.filename) (\(file.size) bytes)")
                AppLogger.info("Upload", "Getting video duration for: \(file.path)")
                let duration = FFmpegService.getVideoDuration(file.path)
                AppLogger.info("Upload", "Video duration: \(duration.map { String($0) } ?? "nil")")

                AppLogger.info("Upload", "Generating video thumbnail -> \(thumbPath)")
                let success = FFmpegService.generateVideoThumbnail(inputPath: file.path, outputPath: thumbPath)
                AppLogger.info("Upload", "Video thumbnail result: \(success)")
                if !success {
                    results.append(UploadResult(filename: file.filename, success: false, error: "ffmpeg thumbnail failed"))
                    await updateProgress(results: results)
                    continue
                }
                var videoPath: String? = nil
                if videoUploadMode == .videoAndImage {
                    let compressedPath = tempDir + "\(file.filename).compressed.mp4"
                    AppLogger.info("Upload", "Compressing video -> \(compressedPath)")
                    let compressSuccess = FFmpegService.compressVideo(inputPath: file.path, outputPath: compressedPath)
                    AppLogger.info("Upload", "Video compression result: \(compressSuccess)")
                    videoPath = compressSuccess ? compressedPath : file.path
                }
                previews.append(PreviewFile(original: file, thumbnailPath: thumbPath, videoPath: videoPath, videoLength: duration))
            } else {
                AppLogger.info("Upload", "Processing image: \(file.filename) (\(file.size) bytes)")
                AppLogger.info("Upload", "Generating image preview -> \(thumbPath)")
                let success = FFmpegService.generateImagePreview(inputPath: file.path, outputPath: thumbPath)
                AppLogger.info("Upload", "Image preview result: \(success)")
                if !success {
                    AppLogger.info("Upload", "Falling back to file copy for: \(file.filename)")
                    try? FileManager.default.copyItem(atPath: file.path, toPath: thumbPath)
                }
                previews.append(PreviewFile(original: file, thumbnailPath: thumbPath, videoPath: nil, videoLength: nil))
            }
        }

        AppLogger.info("Upload", "Preview generation done. \(previews.count) preview(s) ready, \(results.count) failed")

        do {
            let uploadItems = previews.map { preview in
                ContentPreviewUploadItem(
                    filename: preview.original.filename,
                    type: preview.original.type == .video ? .video : .image,
                    title: preview.original.filename,
                    mimeType: preview.original.mimeType,
                    size: preview.original.size,
                    filePath: preview.original.path,
                    videoLength: preview.videoLength
                )
            }

            AppLogger.info("Upload", "Requesting \(uploadItems.count) presigned URL(s)...")
            let presignedResults = try await APIService.getContentPreviewUploadUrls(itemId: itemId, items: uploadItems)
            AppLogger.info("Upload", "Got \(presignedResults.count) presigned URL(s)")

            guard presignedResults.count == previews.count else {
                AppLogger.error("Upload", "Presigned URL count mismatch: got \(presignedResults.count), expected \(previews.count)")
                await MainActor.run {
                    errorMessage = "Mismatched presigned URL count"
                    step = .done
                }
                return
            }

            for (index, preview) in previews.enumerated() {
                let presigned = presignedResults[index]

                do {
                    AppLogger.info("Upload", "[\(index+1)/\(previews.count)] Uploading thumbnail for: \(preview.original.filename)")
                    let thumbData = try Data(contentsOf: URL(fileURLWithPath: preview.thumbnailPath))
                    AppLogger.info("Upload", "Thumbnail size: \(thumbData.count) bytes, uploading to: \(presigned.imageUrl.prefix(80))...")
                    try await APIService.uploadToPresignedUrl(
                        url: presigned.imageUrl,
                        data: thumbData,
                        contentType: "image/jpeg"
                    )
                    AppLogger.info("Upload", "Thumbnail upload success for: \(preview.original.filename)")
                } catch {
                    AppLogger.error("Upload", "Thumbnail upload failed for \(preview.original.filename): \(error)")
                    results.append(UploadResult(filename: preview.original.filename, success: false, error: "Image upload: \(error.localizedDescription)"))
                    await updateProgress(results: results)
                    continue
                }

                if let videoPath = preview.videoPath, let videoUrl = presigned.videoUrl {
                    do {
                        AppLogger.info("Upload", "[\(index+1)/\(previews.count)] Uploading video for: \(preview.original.filename)")
                        let videoData = try Data(contentsOf: URL(fileURLWithPath: videoPath))
                        AppLogger.info("Upload", "Video size: \(videoData.count) bytes, uploading to: \(videoUrl.prefix(80))...")
                        try await APIService.uploadToPresignedUrl(
                            url: videoUrl,
                            data: videoData,
                            contentType: preview.original.mimeType
                        )
                        AppLogger.info("Upload", "Video upload success for: \(preview.original.filename)")
                    } catch {
                        AppLogger.error("Upload", "Video upload failed for \(preview.original.filename): \(error)")
                        results.append(UploadResult(filename: preview.original.filename, success: false, error: "Video upload: \(error.localizedDescription)"))
                        await updateProgress(results: results)
                        continue
                    }
                }

                results.append(UploadResult(filename: preview.original.filename, success: true, error: nil))
                await updateProgress(results: results)
            }
        } catch {
            AppLogger.error("Upload", "API error: \(error)")
            await MainActor.run {
                errorMessage = "API error: \(error.localizedDescription)"
                uploadResults = results
                step = .done
            }
            return
        }

        AppLogger.info("Upload", "Upload complete. \(results.filter { $0.success }.count)/\(results.count) succeeded")
        await MainActor.run {
            uploadResults = results
            step = .done
        }
    }

    func updateProgress(results: [UploadResult]) async {
        await MainActor.run {
            uploadProgress = results.count
            uploadResults = results
        }
    }
}
