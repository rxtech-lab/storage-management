import Foundation

enum FFmpegService {
    private static let processTimeout: TimeInterval = 30
    private static let videoCompressTimeout: TimeInterval = 300

    private static func runProcess(_ process: Process, label: String, timeout: TimeInterval? = nil) -> Bool {
        do {
            try process.run()
        } catch {
            AppLogger.ffmpeg.error("\(label): failed to launch: \(error)")

            return false
        }

        let effectiveTimeout = timeout ?? processTimeout
        let deadline = Date().addingTimeInterval(effectiveTimeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }
        if process.isRunning {
            AppLogger.ffmpeg.error("\(label): timed out after \(effectiveTimeout)s, terminating")
            process.terminate()
            return false
        }
        return true
    }

    static func generateVideoThumbnail(inputPath: String, outputPath: String) -> Bool {
        let process = Process()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "ffmpeg", "-y", "-nostdin", "-i", inputPath,
            "-ss", "00:00:01", "-vframes", "1",
            "-vf", "scale=480:-1",
            outputPath,
        ]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = stderrPipe

        guard runProcess(process, label: "generateVideoThumbnail") else { return false }

        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0 {
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""
            AppLogger.ffmpeg.error("generateVideoThumbnail exit \(process.terminationStatus): \(stderr.suffix(500))")
        }
        return process.terminationStatus == 0
    }

    static func generateImagePreview(inputPath: String, outputPath: String) -> Bool {
        let process = Process()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "ffmpeg", "-y", "-nostdin", "-i", inputPath,
            "-vf", "scale=480:-1",
            "-q:v", "5",
            outputPath,
        ]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = stderrPipe

        guard runProcess(process, label: "generateImagePreview") else { return false }

        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0 {
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""
            AppLogger.ffmpeg.error("generateImagePreview exit \(process.terminationStatus): \(stderr.suffix(500))")
        }
        return process.terminationStatus == 0
    }

    static func getVideoDuration(_ path: String) -> Double? {
        let process = Process()
        let pipe = Pipe()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "ffprobe", "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            path,
        ]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = pipe
        process.standardError = stderrPipe

        guard runProcess(process, label: "getVideoDuration") else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
            return Double(str)
        }
        return nil
    }

    /// Compress video to low quality MP4, max 720p, using H.264.
    static func compressVideo(inputPath: String, outputPath: String) -> Bool {
        let process = Process()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "ffmpeg", "-y", "-nostdin", "-i", inputPath,
            "-t", "300",
            "-vf", "scale='min(720,iw)':-2",
            "-c:v", "libx264", "-preset", "fast", "-crf", "28",
            "-c:a", "aac", "-b:a", "96k",
            "-movflags", "+faststart",
            outputPath,
        ]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = stderrPipe

        guard runProcess(process, label: "compressVideo", timeout: videoCompressTimeout) else { return false }

        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0 {
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""
            AppLogger.ffmpeg.error("compressVideo exit \(process.terminationStatus): \(stderr.suffix(500))")
        }
        return process.terminationStatus == 0
    }

    static func mimeTypeForExtension(_ ext: String) -> String {
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "heic": return "image/heic"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "avi": return "video/x-msvideo"
        case "mkv": return "video/x-matroska"
        case "webm": return "video/webm"
        default: return "application/octet-stream"
        }
    }
}
