import Foundation

enum ClipboardService {
    static func copy(_ content: String) {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pbcopy")
        let pipe = Pipe()
        process.standardInput = pipe
        try? process.run()
        pipe.fileHandleForWriting.write(content.data(using: .utf8)!)
        pipe.fileHandleForWriting.closeFile()
        process.waitUntilExit()
        #elseif os(Linux)
        let process = Process()
        if FileManager.default.fileExists(atPath: "/usr/bin/xclip") {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xclip")
            process.arguments = ["-selection", "clipboard"]
        } else if FileManager.default.fileExists(atPath: "/usr/bin/xsel") {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xsel")
            process.arguments = ["--clipboard", "--input"]
        } else {
            return
        }
        let pipe = Pipe()
        process.standardInput = pipe
        try? process.run()
        pipe.fileHandleForWriting.write(content.data(using: .utf8)!)
        pipe.fileHandleForWriting.closeFile()
        process.waitUntilExit()
        #elseif os(Windows)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "C:\\Windows\\System32\\clip.exe")
        let pipe = Pipe()
        process.standardInput = pipe
        try? process.run()
        pipe.fileHandleForWriting.write(content.data(using: .utf8)!)
        pipe.fileHandleForWriting.closeFile()
        process.waitUntilExit()
        #endif
    }
}
