import Foundation
import Logging

public protocol ContentUploadPreprocessorProtocol: Sendable {
    func prepareFile(
        file: ContentUploadInputFile,
        mode: ContentUploadVideoMode,
        temporaryDirectory: URL
    ) async throws -> ContentUploadPreparedAsset
}

public enum ContentUploadPreprocessError: LocalizedError, Sendable {
    case ffmpegNotInstalled(log: String?)
    case ffprobeNotInstalled(log: String?)
    case thumbnailGenerationFailed(log: String?)
    case videoProbeFailed(log: String?)
    case fileOperationFailed(String)
    case unsupportedPlatform

    public var errorDescription: String? {
        switch self {
        case .ffmpegNotInstalled:
            return "ffmpeg is not installed or not available in PATH"
        case .ffprobeNotInstalled:
            return "ffprobe is not installed or not available in PATH"
        case .thumbnailGenerationFailed:
            return "Failed to generate thumbnail"
        case .videoProbeFailed:
            return "Failed to probe video metadata"
        case let .fileOperationFailed(message):
            return message
        case .unsupportedPlatform:
            return "Content preprocessing is only supported on macOS"
        }
    }

    public var logMessage: String? {
        switch self {
        case let .ffmpegNotInstalled(log):
            return log
        case let .ffprobeNotInstalled(log):
            return log
        case let .thumbnailGenerationFailed(log):
            return log
        case let .videoProbeFailed(log):
            return log
        default:
            return nil
        }
    }
}

public struct FFmpegContentUploadPreprocessor: ContentUploadPreprocessorProtocol {
    private let logger = Logger(label: "FFmpegContentUploadPreprocessor")

    public init() {}

    public func prepareFile(
        file: ContentUploadInputFile,
        mode: ContentUploadVideoMode,
        temporaryDirectory: URL
    ) async throws -> ContentUploadPreparedAsset {
        try await Task.detached(priority: .userInitiated) {
            #if os(macOS)
                let fm = FileManager.default
                try fm.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

                let thumbnailURL = temporaryDirectory.appendingPathComponent("\(file.filename).thumb.jpg")

                switch file.mediaType {
                case .image:
                    let previewResult = Self.generateImagePreview(inputPath: file.fileURL.path, outputPath: thumbnailURL.path)
                    if !previewResult.success {
                        logger.warning(
                            "Image preview generation failed, fallback to file copy",
                            metadata: [
                                "file": "\(file.filename)",
                                "log": "\(previewResult.logMessage ?? "")",
                            ]
                        )
                        do {
                            if fm.fileExists(atPath: thumbnailURL.path) {
                                try fm.removeItem(at: thumbnailURL)
                            }
                            try fm.copyItem(at: file.fileURL, to: thumbnailURL)
                        } catch {
                            throw ContentUploadPreprocessError.fileOperationFailed(error.localizedDescription)
                        }
                    }
                    return ContentUploadPreparedAsset(
                        thumbnailURL: thumbnailURL,
                        uploadVideoURL: nil,
                        videoLength: nil
                    )
                case .video:
                    let probeResult = Self.getVideoDuration(file.fileURL.path)
                    if probeResult.commandMissing {
                        throw ContentUploadPreprocessError.ffprobeNotInstalled(log: probeResult.log)
                    }
                    if !probeResult.success {
                        throw ContentUploadPreprocessError.videoProbeFailed(log: probeResult.log)
                    }
                    let videoLength = probeResult.duration ?? 0
                    let thumbResult = Self.generateVideoThumbnail(inputPath: file.fileURL.path, outputPath: thumbnailURL.path)
                    if !thumbResult.success {
                        if thumbResult.commandMissing("ffmpeg") {
                            throw ContentUploadPreprocessError.ffmpegNotInstalled(log: thumbResult.logMessage)
                        }
                        throw ContentUploadPreprocessError.thumbnailGenerationFailed(log: thumbResult.logMessage)
                    }

                    var uploadVideoURL: URL? = nil
                    if mode == .videoAndImage {
                        let compressedURL = temporaryDirectory.appendingPathComponent("\(file.filename).compressed.mp4")
                        if Self.compressVideo(inputPath: file.fileURL.path, outputPath: compressedURL.path) {
                            uploadVideoURL = compressedURL
                        } else {
                            logger.warning("Video compression failed, using original file", metadata: ["file": "\(file.filename)"])
                            uploadVideoURL = file.fileURL
                        }
                    }

                    return ContentUploadPreparedAsset(
                        thumbnailURL: thumbnailURL,
                        uploadVideoURL: uploadVideoURL,
                        videoLength: videoLength
                    )
                }
            #else
                _ = file
                _ = mode
                _ = temporaryDirectory
                throw ContentUploadPreprocessError.unsupportedPlatform
            #endif
        }.value
    }
}

#if os(macOS)
    private enum FFmpegHWEncoder {
        case videotoolbox
        case none

        var videoArgs: [String] {
            switch self {
            case .videotoolbox:
                return ["-c:v", "h264_videotoolbox", "-q:v", "65"]
            case .none:
                return ["-c:v", "libx264", "-preset", "fast", "-crf", "28"]
            }
        }
    }

    private struct ProcessRunResult {
        let didLaunch: Bool
        let timedOut: Bool
        let terminationStatus: Int32
        let stdout: String
        let stderr: String
        let launchError: String?

        var success: Bool {
            didLaunch && !timedOut && terminationStatus == 0
        }

        var logMessage: String? {
            var parts: [String] = []
            if let launchError, !launchError.isEmpty {
                parts.append(launchError)
            }
            let cleanedStderr = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanedStderr.isEmpty {
                parts.append(cleanedStderr)
            }
            let cleanedStdout = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanedStdout.isEmpty {
                parts.append(cleanedStdout)
            }
            guard !parts.isEmpty else { return nil }
            return Self.truncated(parts.joined(separator: "\n"), maxCharacters: 6000)
        }

        func commandMissing(_ command: String) -> Bool {
            let needle = command.lowercased()
            if !didLaunch {
                return launchError?.lowercased().contains(needle) ?? false
            }
            if terminationStatus == 127 {
                return true
            }
            guard let log = logMessage?.lowercased() else { return false }
            if log.contains("\(needle): command not found") {
                return true
            }
            return log.contains(needle) && log.contains("no such file or directory")
        }

        private static func truncated(_ value: String, maxCharacters: Int) -> String {
            guard value.count > maxCharacters else { return value }
            let suffix = String(value.suffix(maxCharacters))
            return "...(truncated)...\n" + suffix
        }
    }

    private struct VideoProbeResult {
        let duration: Double?
        let success: Bool
        let commandMissing: Bool
        let log: String?
    }

    private extension FFmpegContentUploadPreprocessor {
        static let processTimeout: TimeInterval = 30
        static let videoCompressTimeout: TimeInterval = 300

        static let detectedEncoder: FFmpegHWEncoder = {
            let result = runProcess(command: "ffmpeg", arguments: ["-hide_banner", "-encoders"])
            guard result.success else {
                return .none
            }
            let output = result.stdout
            if output.contains("h264_videotoolbox") {
                return .videotoolbox
            }
            return .none
        }()

        static func runProcess(command: String, arguments: [String], timeout: TimeInterval? = nil) -> ProcessRunResult {
            let candidates = resolveExecutableCandidates(command: command)
            var launchErrors: [String] = []

            for executableURL in candidates {
                let result = runProcess(
                    executableURL: executableURL,
                    arguments: arguments,
                    timeout: timeout
                )
                if result.didLaunch {
                    return result
                }
                if let launchError = result.launchError, !launchError.isEmpty {
                    let exists = FileManager.default.fileExists(atPath: executableURL.path)
                    let executable = FileManager.default.isExecutableFile(atPath: executableURL.path)
                    launchErrors.append("\(executableURL.path) [exists=\(exists), executable=\(executable)]: \(launchError)")
                }
            }

            if let shellResolvedPath = resolveUsingLoginShell(command: command) {
                let shellURL = URL(fileURLWithPath: shellResolvedPath)
                let shellResult = runProcess(
                    executableURL: shellURL,
                    arguments: arguments,
                    timeout: timeout
                )
                if shellResult.didLaunch {
                    return shellResult
                }
                if let launchError = shellResult.launchError, !launchError.isEmpty {
                    let exists = FileManager.default.fileExists(atPath: shellResolvedPath)
                    let executable = FileManager.default.isExecutableFile(atPath: shellResolvedPath)
                    launchErrors.append("\(shellResolvedPath) [resolved by zsh, exists=\(exists), executable=\(executable)]: \(launchError)")
                }
            }

            let message: String
            if launchErrors.isEmpty {
                message = "Unable to find \(command) executable in PATH or common locations"
            } else {
                message = "Unable to launch \(command). Tried:\n" + launchErrors.joined(separator: "\n")
            }

            return ProcessRunResult(
                didLaunch: false,
                timedOut: false,
                terminationStatus: -1,
                stdout: "",
                stderr: "",
                launchError: message
            )
        }

        static func runProcess(executableURL: URL, arguments: [String], timeout: TimeInterval? = nil) -> ProcessRunResult {
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.executableURL = executableURL
            process.arguments = arguments
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            process.environment = defaultExecutionEnvironment()

            do {
                try process.run()
            } catch {
                return ProcessRunResult(
                    didLaunch: false,
                    timedOut: false,
                    terminationStatus: -1,
                    stdout: "",
                    stderr: "",
                    launchError: error.localizedDescription
                )
            }

            let effectiveTimeout = timeout ?? processTimeout
            let deadline = Date().addingTimeInterval(effectiveTimeout)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.1)
            }

            let timedOut = process.isRunning
            if process.isRunning {
                process.terminate()
            }

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

            return ProcessRunResult(
                didLaunch: true,
                timedOut: timedOut,
                terminationStatus: process.terminationStatus,
                stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                stderr: String(data: stderrData, encoding: .utf8) ?? "",
                launchError: nil
            )
        }

        static func resolveExecutableCandidates(command: String) -> [URL] {
            if command.hasPrefix("/") {
                return [URL(fileURLWithPath: command)]
            }

            var candidatePaths: [String] = []
            candidatePaths.append(contentsOf: bundledExecutableCandidates(command: command))
            if let envPath = ProcessInfo.processInfo.environment["PATH"] {
                let pathDirs = envPath.split(separator: ":").map(String.init)
                candidatePaths.append(contentsOf: pathDirs.map { "\($0)/\(command)" })
            }

            candidatePaths.append(contentsOf: [
                "/opt/homebrew/bin/\(command)",
                "/usr/local/bin/\(command)",
                "/usr/bin/\(command)",
                "/bin/\(command)",
                "/opt/local/bin/\(command)",
            ])

            if command == "ffmpeg" || command == "ffprobe" {
                candidatePaths.append(contentsOf: [
                    "/opt/homebrew/opt/ffmpeg/bin/\(command)",
                    "/usr/local/opt/ffmpeg/bin/\(command)",
                ])
                candidatePaths.append(contentsOf: cellarCandidates(command: command, cellarRoot: "/opt/homebrew/Cellar/ffmpeg"))
                candidatePaths.append(contentsOf: cellarCandidates(command: command, cellarRoot: "/usr/local/Cellar/ffmpeg"))
            }

            if let whichPath = resolveUsingWhich(command: command) {
                candidatePaths.append(whichPath)
            }

            var seen = Set<String>()
            return candidatePaths.compactMap { path in
                guard seen.insert(path).inserted else { return nil }
                return URL(fileURLWithPath: path)
            }
        }

        static func cellarCandidates(command: String, cellarRoot: String) -> [String] {
            let fm = FileManager.default
            guard let versions = try? fm.contentsOfDirectory(atPath: cellarRoot), !versions.isEmpty else {
                return []
            }
            return versions.sorted(by: >).map { "\(cellarRoot)/\($0)/bin/\(command)" }
        }

        static func bundledExecutableCandidates(command: String) -> [String] {
            let bundle = Bundle.main
            var candidates: [String] = []

            if let url = bundle.resourceURL?.appendingPathComponent(command), !url.path.isEmpty {
                candidates.append(url.path)
            }
            if let url = bundle.privateFrameworksURL?.appendingPathComponent(command), !url.path.isEmpty {
                candidates.append(url.path)
            }
            if let url = bundle.builtInPlugInsURL?.appendingPathComponent(command), !url.path.isEmpty {
                candidates.append(url.path)
            }
            return candidates
        }

        static func resolveUsingWhich(command: String) -> String? {
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            process.arguments = [command]
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            process.environment = defaultExecutionEnvironment()

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                return nil
            }

            guard process.terminationStatus == 0 else { return nil }
            let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !output.isEmpty
            else {
                return nil
            }
            return output
        }

        static func resolveUsingLoginShell(command: String) -> String? {
            let process = Process()
            let stdoutPipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", "command -v \(command)"]
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = stdoutPipe
            process.standardError = FileHandle.nullDevice
            process.environment = defaultExecutionEnvironment()

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                return nil
            }

            guard process.terminationStatus == 0 else { return nil }
            let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !output.isEmpty
            else {
                return nil
            }
            return output
        }

        static func defaultExecutionEnvironment() -> [String: String] {
            var environment = ProcessInfo.processInfo.environment
            let defaultPath = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin", "/opt/local/bin"]
                .joined(separator: ":")
            if let existingPath = environment["PATH"], !existingPath.isEmpty {
                environment["PATH"] = existingPath + ":" + defaultPath
            } else {
                environment["PATH"] = defaultPath
            }
            return environment
        }

        static func generateVideoThumbnail(inputPath: String, outputPath: String) -> ProcessRunResult {
            runProcess(command: "ffmpeg", arguments: [
                "-y", "-nostdin", "-i", inputPath,
                "-ss", "00:00:01", "-vframes", "1",
                "-vf", "scale=480:-1",
                outputPath,
            ])
        }

        static func generateImagePreview(inputPath: String, outputPath: String) -> ProcessRunResult {
            runProcess(command: "ffmpeg", arguments: [
                "-y", "-nostdin", "-i", inputPath,
                "-vf", "scale=480:-1",
                "-q:v", "5",
                outputPath,
            ])
        }

        static func getVideoDuration(_ path: String) -> VideoProbeResult {
            let result = runProcess(command: "ffprobe", arguments: [
                "-v", "error",
                "-show_entries", "format=duration",
                "-of", "default=noprint_wrappers=1:nokey=1",
                path,
            ])

            let duration = Double(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
            return VideoProbeResult(
                duration: duration,
                success: result.success && duration != nil,
                commandMissing: result.commandMissing("ffprobe"),
                log: result.logMessage
            )
        }

        static func compressVideo(inputPath: String, outputPath: String) -> Bool {
            if detectedEncoder == .videotoolbox {
                if compressVideo(encoder: .videotoolbox, inputPath: inputPath, outputPath: outputPath).success {
                    return true
                }
            }
            return compressVideo(encoder: .none, inputPath: inputPath, outputPath: outputPath).success
        }

        static func compressVideo(encoder: FFmpegHWEncoder, inputPath: String, outputPath: String) -> ProcessRunResult {
            var args = [
                "-y", "-nostdin", "-i", inputPath,
                "-t", "300",
                "-vf", "scale='min(720,iw)':-2",
            ]
            args += encoder.videoArgs
            args += [
                "-c:a", "aac", "-b:a", "96k",
                "-movflags", "+faststart",
                outputPath,
            ]
            return runProcess(command: "ffmpeg", arguments: args, timeout: videoCompressTimeout)
        }
    }
#endif
