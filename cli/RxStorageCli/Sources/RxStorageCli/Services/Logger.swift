import Foundation
import os

enum AppLogger {
    private static let subsystem = "app.rxlab.RxStorageCli"
    static let api = Logger(subsystem: subsystem, category: "API")
    static let auth = Logger(subsystem: subsystem, category: "Auth")
    static let general = Logger(subsystem: subsystem, category: "General")

    private static let logFileURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".rxstorage/logs")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("app.log")
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    private static let fileLock = NSLock()

    static func writeToFile(_ level: String, category: String, message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] [\(level)] [\(category)] \(message)\n"

        fileLock.lock()
        defer { fileLock.unlock() }

        if let handle = try? FileHandle(forWritingTo: logFileURL) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try? line.data(using: .utf8)?.write(to: logFileURL)
        }
    }

    static func info(_ category: String, _ message: String) {
        writeToFile("INFO", category: category, message: message)
    }

    static func error(_ category: String, _ message: String) {
        writeToFile("ERROR", category: category, message: message)
    }

    static func debug(_ category: String, _ message: String) {
        writeToFile("DEBUG", category: category, message: message)
    }

    static var logFilePath: String {
        logFileURL.path
    }
}
