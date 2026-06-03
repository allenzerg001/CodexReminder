import Foundation
import CodexReminderCore

protocol ToolMonitor: Sendable {
    var toolName: String { get }
    func detectInstances() -> [ToolInfo]
}
