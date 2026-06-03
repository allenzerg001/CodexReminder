import Foundation
import CodexReminderCore

struct FileBasedMonitor: ToolMonitor {
    let toolName = "HookEvents"

    private let watchDir: String

    init() {
        let basePath = Foundation.ProcessInfo.processInfo.environment["CODEX_REMINDER_HOME"]
            ?? "\(FileManager.default.homeDirectoryForCurrentUser.path)/.codexreminder"
        watchDir = "\(basePath)/notifications"
        try? FileManager.default.createDirectory(
            atPath: watchDir,
            withIntermediateDirectories: true
        )
    }

    func detectInstances() -> [ToolInfo] {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: watchDir) else {
            return []
        }

        let jsonFiles = files.filter { $0.hasSuffix(".json") }

        var results: [ToolInfo] = []
        let now = Date()

        for file in jsonFiles {
            let path = "\(watchDir)/\(file)"
            guard let data = FileManager.default.contents(atPath: path) else {
                continue
            }

            guard let tool = HookNotificationParser.parse(data: data, requestPath: path, now: now) else {
                if isExpiredNotification(data: data, now: now) {
                    try? FileManager.default.removeItem(atPath: path)
                }
                continue
            }

            results.append(tool)
        }
        return results
    }

    private func isExpiredNotification(data: Data, now: Date) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        if let expiresAt = (json["expiresAt"] as? NSNumber)?.doubleValue {
            return now.timeIntervalSince1970 > expiresAt
        }

        guard let timestamp = (json["timestamp"] as? NSNumber)?.doubleValue else {
            return false
        }

        return now.timeIntervalSince(Date(timeIntervalSince1970: timestamp)) > HookNotificationParser.defaultTTL
    }
}
