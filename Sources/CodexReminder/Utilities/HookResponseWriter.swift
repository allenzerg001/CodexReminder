import Foundation
import CodexReminderCore

enum HookResponseWriter {
    static func write(choice: ToolChoice, for tool: ToolInfo) {
        guard let responsePath = tool.responsePath else {
            if let requestPath = tool.requestPath {
                try? FileManager.default.removeItem(atPath: requestPath)
            }
            fileLog("Cleared pass-through hook notification for \(tool.name): \(choice.value)")
            return
        }

        let url = URL(fileURLWithPath: responsePath)

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let response = HookChoiceResponse(
                toolId: tool.id,
                tool: tool.name,
                choiceId: choice.id,
                value: choice.value,
                timestamp: Date().timeIntervalSince1970
            )
            let data = try JSONEncoder().encode(response)
            try data.write(to: url, options: .atomic)

            if let requestPath = tool.requestPath {
                try? FileManager.default.removeItem(atPath: requestPath)
            }
            fileLog("Wrote hook response for \(tool.name): \(choice.value)")
        } catch {
            fileLog("Failed to write hook response for \(tool.name): \(error.localizedDescription)")
        }
    }

}

private struct HookChoiceResponse: Encodable {
    let toolId: String
    let tool: String
    let choiceId: String
    let value: String
    let timestamp: TimeInterval
}
