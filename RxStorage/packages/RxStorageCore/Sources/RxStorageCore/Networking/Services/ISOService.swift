#if os(macOS)
    import Foundation
    import Logging

    public enum ISOService {
        private static let logger = Logger(label: "ISOService")

        /// Mount an ISO file and return the mount point path, or nil on failure.
        /// Runs hdiutil on a background thread to avoid blocking the UI.
        public static func mount(isoPath: String) async -> String? {
            await Task.detached {
                mountSync(isoPath: isoPath)
            }.value
        }

        /// Unmount a previously mounted ISO.
        /// Runs hdiutil on a background thread to avoid blocking the UI.
        public static func unmount(mountPoint: String) async {
            await Task.detached {
                unmountSync(mountPoint: mountPoint)
            }.value
        }

        // MARK: - Synchronous implementations

        private static func mountSync(isoPath: String) -> String? {
            let mountPoint = NSTemporaryDirectory() + "rxstorage-iso-\(UUID().uuidString)"
            do {
                try FileManager.default.createDirectory(atPath: mountPoint, withIntermediateDirectories: true)
            } catch {
                logger.error("Failed to create ISO mount point: \(error)")
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
                logger.error("Failed to launch hdiutil attach: \(error)")
                try? FileManager.default.removeItem(atPath: mountPoint)
                return nil
            }

            process.waitUntilExit()

            if process.terminationStatus != 0 {
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                logger.error("hdiutil attach failed (\(process.terminationStatus)): \(stderr.suffix(500))")
                try? FileManager.default.removeItem(atPath: mountPoint)
                return nil
            }

            logger.info("Mounted ISO at: \(mountPoint)")
            return mountPoint
        }

        private static func unmountSync(mountPoint: String) {
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
                logger.error("Failed to unmount ISO: \(error)")
            }

            try? FileManager.default.removeItem(atPath: mountPoint)
            logger.info("Unmounted ISO at: \(mountPoint)")
        }
    }
#endif
