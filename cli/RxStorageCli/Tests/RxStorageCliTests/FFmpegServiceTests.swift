import Foundation
import Testing

@testable import RxStorageCli

@Suite("FFmpegService Tests")
struct FFmpegServiceTests {
    /// Creates a minimal test MP4 using FFmpeg's built-in test source.
    /// Returns the path to the generated file, or nil if generation failed.
    private func generateTestVideo(duration: Int = 1) -> String? {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FFmpegServiceTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let outputPath = tmpDir.appendingPathComponent("input.mp4").path

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "ffmpeg", "-y", "-nostdin",
            "-f", "lavfi", "-i", "testsrc=duration=\(duration):size=320x240:rate=25",
            "-f", "lavfi", "-i", "sine=frequency=440:duration=\(duration)",
            "-c:v", "libx264", "-preset", "ultrafast", "-pix_fmt", "yuv420p",
            "-c:a", "aac", "-b:a", "64k",
            "-shortest",
            outputPath,
        ]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        return process.terminationStatus == 0 ? outputPath : nil
    }

    @Test("compressVideo produces output file")
    func compressVideoProducesOutput() throws {
        let inputPath = try #require(generateTestVideo(), "Failed to generate test video")
        defer { try? FileManager.default.removeItem(atPath: (inputPath as NSString).deletingLastPathComponent) }

        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FFmpegServiceTests-out-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        let outputPath = outputDir.appendingPathComponent("compressed.mp4").path
        defer { try? FileManager.default.removeItem(at: outputDir) }

        let result = FFmpegService.compressVideo(inputPath: inputPath, outputPath: outputPath)

        #expect(result == true, "compressVideo should succeed")
        #expect(FileManager.default.fileExists(atPath: outputPath), "Output file should exist")

        let attrs = try FileManager.default.attributesOfItem(atPath: outputPath)
        let size = attrs[.size] as? UInt64 ?? 0
        #expect(size > 0, "Output file should not be empty")
    }

    @Test("NVENC preset p4 is recognized by FFmpeg")
    func nvencPresetP4Recognized() throws {
        let inputPath = try #require(generateTestVideo(), "Failed to generate test video")
        defer { try? FileManager.default.removeItem(atPath: (inputPath as NSString).deletingLastPathComponent) }

        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FFmpegServiceTests-p4-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        let outputPath = outputDir.appendingPathComponent("out.mp4").path
        defer { try? FileManager.default.removeItem(at: outputDir) }

        let process = Process()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "ffmpeg", "-y", "-nostdin", "-i", inputPath,
            "-t", "1",
            "-vf", "scale='min(720,iw)':-2",
            "-c:v", "h264_nvenc", "-cq", "28", "-preset", "p4",
            "-c:a", "aac", "-b:a", "96k",
            "-movflags", "+faststart",
            outputPath,
        ]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        // The command may fail because there is no GPU, but the preset itself should be valid.
        // If "p4" is unrecognized, stderr will contain "Unable to parse option value".
        #expect(
            !stderr.contains("Unable to parse option value"),
            "Preset 'p4' should be recognized by this FFmpeg version. stderr: \(stderr.suffix(300))"
        )
    }

    @Test("NVENC legacy preset medium is recognized by FFmpeg")
    func nvencPresetMediumRecognized() throws {
        let inputPath = try #require(generateTestVideo(), "Failed to generate test video")
        defer { try? FileManager.default.removeItem(atPath: (inputPath as NSString).deletingLastPathComponent) }

        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FFmpegServiceTests-medium-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        let outputPath = outputDir.appendingPathComponent("out.mp4").path
        defer { try? FileManager.default.removeItem(at: outputDir) }

        let process = Process()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "ffmpeg", "-y", "-nostdin", "-i", inputPath,
            "-t", "1",
            "-vf", "scale='min(720,iw)':-2",
            "-c:v", "h264_nvenc", "-cq", "28", "-preset", "medium",
            "-c:a", "aac", "-b:a", "96k",
            "-movflags", "+faststart",
            outputPath,
        ]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        // The command may fail because there is no GPU, but the preset itself should be valid.
        #expect(
            !stderr.contains("Unable to parse option value"),
            "Preset 'medium' should be recognized by this FFmpeg version. stderr: \(stderr.suffix(300))"
        )
    }

    @Test("libx264 software fallback produces valid output")
    func libx264FallbackWorks() throws {
        let inputPath = try #require(generateTestVideo(), "Failed to generate test video")
        defer { try? FileManager.default.removeItem(atPath: (inputPath as NSString).deletingLastPathComponent) }

        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FFmpegServiceTests-sw-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        let outputPath = outputDir.appendingPathComponent("out.mp4").path
        defer { try? FileManager.default.removeItem(at: outputDir) }

        let process = Process()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "ffmpeg", "-y", "-nostdin", "-i", inputPath,
            "-t", "1",
            "-vf", "scale='min(720,iw)':-2",
            "-c:v", "libx264", "-preset", "fast", "-crf", "28",
            "-c:a", "aac", "-b:a", "96k",
            "-movflags", "+faststart",
            outputPath,
        ]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus == 0, "libx264 encoding should succeed")
        #expect(FileManager.default.fileExists(atPath: outputPath), "Output file should exist")
    }

    @Test("generateVideoThumbnail produces output")
    func generateVideoThumbnailWorks() throws {
        let inputPath = try #require(generateTestVideo(duration: 2), "Failed to generate test video")
        defer { try? FileManager.default.removeItem(atPath: (inputPath as NSString).deletingLastPathComponent) }

        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FFmpegServiceTests-thumb-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        let outputPath = outputDir.appendingPathComponent("thumb.jpg").path
        defer { try? FileManager.default.removeItem(at: outputDir) }

        let result = FFmpegService.generateVideoThumbnail(inputPath: inputPath, outputPath: outputPath)

        #expect(result == true, "generateVideoThumbnail should succeed")
        #expect(FileManager.default.fileExists(atPath: outputPath), "Thumbnail should exist")
    }

    @Test("getVideoDuration returns correct duration")
    func getVideoDurationWorks() throws {
        let inputPath = try #require(generateTestVideo(duration: 2), "Failed to generate test video")
        defer { try? FileManager.default.removeItem(atPath: (inputPath as NSString).deletingLastPathComponent) }

        let duration = FFmpegService.getVideoDuration(inputPath)

        let d = try #require(duration, "Duration should not be nil")
        // Allow some tolerance for container overhead
        #expect(d > 1.5 && d < 2.5, "Duration should be approximately 2 seconds, got \(d)")
    }
}
