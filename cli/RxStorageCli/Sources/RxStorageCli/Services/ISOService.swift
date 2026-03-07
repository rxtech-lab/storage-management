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

        #if os(macOS)
        let success = mountMacOS(isoPath: isoPath, mountPoint: mountPoint)
        #else
        let success = mountLinux(isoPath: isoPath, mountPoint: mountPoint)
        #endif

        if success {
            AppLogger.upload.info("Mounted ISO at: \(mountPoint)")
            return mountPoint
        } else {
            try? FileManager.default.removeItem(atPath: mountPoint)
            return nil
        }
    }

    /// Unmount a previously mounted ISO.
    static func unmount(mountPoint: String) {
        #if os(macOS)
        unmountMacOS(mountPoint: mountPoint)
        #endif
        // On Linux we extracted files, so just remove the directory
        try? FileManager.default.removeItem(atPath: mountPoint)
        AppLogger.upload.info("Unmounted ISO at: \(mountPoint)")
    }

    // MARK: - macOS (hdiutil)

    #if os(macOS)
    private static func mountMacOS(isoPath: String, mountPoint: String) -> Bool {
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
            return false
        }

        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""
            AppLogger.upload.error("hdiutil attach failed (\(process.terminationStatus)): \(stderr.suffix(500))")
            return false
        }

        return true
    }

    private static func unmountMacOS(mountPoint: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["detach", mountPoint]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            AppLogger.upload.error("Failed to unmount ISO: \(error)")
        }
    }
    #endif

    // MARK: - Linux (7z extract)

    #if !os(macOS)
    private static func mountLinux(isoPath: String, mountPoint: String) -> Bool {
        // Use 7z to extract ISO contents (no root required, unlike mount -o loop)
        let process = Process()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/7z")
        process.arguments = ["x", isoPath, "-o\(mountPoint)", "-y"]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            AppLogger.upload.error("Failed to launch 7z: \(error)")
            return false
        }

        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""
            AppLogger.upload.error("7z extract failed (\(process.terminationStatus)): \(stderr.suffix(500))")
            return false
        }

        return true
    }
    #endif
}
