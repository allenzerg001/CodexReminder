import Foundation

func fileLog(_ message: String) {
    let logDir = Foundation.ProcessInfo.processInfo.environment["CODEX_REMINDER_HOME"]
        ?? FileManager.default.homeDirectoryForCurrentUser.path + "/.codexreminder"
    try? FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true)

    let logPath = logDir + "/app.log"
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] \(message)\n"
    if let handle = FileHandle(forWritingAtPath: logPath) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        handle.closeFile()
    } else {
        FileManager.default.createFile(atPath: logPath, contents: line.data(using: .utf8))
    }
}
