import Foundation

enum ISOService {
    /// Mount an ISO file and return the mount point path, or nil on failure.
    static func mount(isoPath: String) -> String? {
        let mountPoint = NSTemporaryDirectory() + "rxstorage-iso-\(UUID().uuidString)"
        do {
            try FileManager.default.createDirectory(atPath: mountPoint, withIntermediateDirectories: true)
        } catch {
            AppLogger.upload.error("Failed to create ISO mount point: \(error)")
            return nil
        }

        let process = Process()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", isoPath, "-mountpoint", mountPoint, "-nobrowse", "-readonly"]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            AppLogger.upload.error("Failed to launch hdiutil attach: \(error)")
            try? FileManager.default.removeItem(atPath: mountPoint)
            return nil
        }

        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""
            AppLogger.upload.error("hdiutil attach failed (\(process.terminationStatus)): \(stderr.suffix(500))")
            try? FileManager.default.removeItem(atPath: mountPoint)
            return nil
        }

        AppLogger.upload.info("Mounted ISO at: \(mountPoint)")
        return mountPoint
    }

    /// Unmount a previously mounted ISO.
    static func unmount(mountPoint: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["detach", mountPoint]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            AppLogger.upload.info("Unmounted ISO at: \(mountPoint)")
        } catch {
            AppLogger.upload.error("Failed to unmount ISO: \(error)")
        }

        try? FileManager.default.removeItem(atPath: mountPoint)
    }
}
