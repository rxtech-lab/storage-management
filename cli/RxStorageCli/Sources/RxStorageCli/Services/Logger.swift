import Foundation
import Logging

enum AppLogger {
    static let api = Logger(label: "app.rxlab.RxStorageCli.API")
    static let auth = Logger(label: "app.rxlab.RxStorageCli.Auth")
    static let general = Logger(label: "app.rxlab.RxStorageCli.General")
    static let upload = Logger(label: "app.rxlab.RxStorageCli.Upload")
    static let ffmpeg = Logger(label: "app.rxlab.RxStorageCli.FFmpeg")

    static let logFileURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".rxstorage/logs")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("app.log")
    }()

    static func bootstrap() {
        LoggingSystem.bootstrap { label in
            FileLogHandler(label: label, fileURL: logFileURL)
        }
    }
}

struct FileLogHandler: LogHandler {
    let label: String
    let fileURL: URL
    var logLevel: Logger.Level = .info
    var metadata: Logger.Metadata = [:]

    private static let lock = NSLock()
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        let timestamp = Self.dateFormatter.string(from: Date())
        let line = "[\(timestamp)] [\(level)] [\(label)] \(message)\n"

        Self.lock.lock()
        defer { Self.lock.unlock() }

        if let handle = try? FileHandle(forWritingTo: fileURL) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try? line.data(using: .utf8)?.write(to: fileURL)
        }
    }
}
