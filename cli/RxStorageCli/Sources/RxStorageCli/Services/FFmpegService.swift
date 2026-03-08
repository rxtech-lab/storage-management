import Foundation

enum FFmpegService {
    private static let processTimeout: TimeInterval = 30
    private static let videoCompressTimeout: TimeInterval = 300

    private enum HWEncoder {
        case videotoolbox
        case nvenc
        case nvencLegacy
        case none

        var codecName: String? {
            switch self {
            case .videotoolbox: return "h264_videotoolbox"
            case .nvenc, .nvencLegacy: return "h264_nvenc"
            case .none: return nil
            }
        }

        var videoArgs: [String] {
            switch self {
            case .videotoolbox:
                return ["-c:v", "h264_videotoolbox", "-q:v", "65"]
            case .nvenc:
                return ["-c:v", "h264_nvenc", "-cq", "28", "-preset", "p4"]
            case .nvencLegacy:
                return ["-c:v", "h264_nvenc", "-cq", "28", "-preset", "medium"]
            case .none:
                return ["-c:v", "libx264", "-preset", "fast", "-crf", "28"]
            }
        }
    }

    private static let detectedEncoder: HWEncoder = {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["ffmpeg", "-hide_banner", "-encoders"]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .none
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        #if os(macOS)
        if output.contains("h264_videotoolbox") {
            AppLogger.ffmpeg.info("GPU acceleration: using VideoToolbox")
            return .videotoolbox
        }
        #endif
        if output.contains("h264_nvenc") {
            AppLogger.ffmpeg.info("GPU acceleration: using NVENC")
            return .nvenc
        }

        AppLogger.ffmpeg.info("GPU acceleration: not available, using libx264")
        return .none
    }()

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

    /// Compress video to low quality MP4, max 720p, using H.264 with automatic GPU acceleration.
    static func compressVideo(inputPath: String, outputPath: String) -> Bool {
        if detectedEncoder.codecName != nil {
            if compressVideoWith(encoder: detectedEncoder, inputPath: inputPath, outputPath: outputPath) {
                return true
            }
            // For NVENC, retry with legacy preset name before falling back to software encoding.
            // Older FFmpeg versions don't support "p4" preset; "medium" is the equivalent legacy name.
            if case .nvenc = detectedEncoder {
                AppLogger.ffmpeg.info("Retrying NVENC with legacy preset 'medium'")
                if compressVideoWith(encoder: .nvencLegacy, inputPath: inputPath, outputPath: outputPath) {
                    return true
                }
            }
            AppLogger.ffmpeg.warning("GPU encoding failed, falling back to libx264")
        }
        return compressVideoWith(encoder: .none, inputPath: inputPath, outputPath: outputPath)
    }

    private static func compressVideoWith(encoder: HWEncoder, inputPath: String, outputPath: String) -> Bool {
        let process = Process()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        var args = [
            "ffmpeg", "-y", "-nostdin", "-i", inputPath,
            "-t", "300",
            "-vf", "scale='min(720,iw)':-2",
        ]
        args += encoder.videoArgs
        args += [
            "-c:a", "aac", "-b:a", "96k",
            "-movflags", "+faststart",
            outputPath,
        ]
        process.arguments = args
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = stderrPipe

        guard runProcess(process, label: "compressVideo(\(encoder))", timeout: videoCompressTimeout) else { return false }

        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0 {
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""
            AppLogger.ffmpeg.error("compressVideo(\(encoder)) exit \(process.terminationStatus): \(stderr.suffix(500))")
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
