import Foundation

public protocol ToolMonitorProtocol {
    var toolName: String { get }
    var authKeywords: [String] { get }
    var processNamePattern: String { get }
    var iconName: String { get }
    func detectInstances() -> [ToolInfo]
}

public struct MonitorConfig: Equatable, Sendable {
    public let toolName: String
    public let processNamePattern: String
    public let authKeywords: [String]
    public let iconName: String

    public init(toolName: String, processNamePattern: String, authKeywords: [String], iconName: String) {
        self.toolName = toolName
        self.processNamePattern = processNamePattern
        self.authKeywords = authKeywords
        self.iconName = iconName
    }

    public static let codex = MonitorConfig(
        toolName: "Codex",
        processNamePattern: "codex",
        authKeywords: OutputAnalyzer.codexAuthKeywords,
        iconName: "brain.head.profile"
    )

    public static let claudeCode = MonitorConfig(
        toolName: "Claude Code",
        processNamePattern: "claude",
        authKeywords: OutputAnalyzer.claudeAuthKeywords,
        iconName: "sparkle"
    )

    public static let qoder = MonitorConfig(
        toolName: "Qoder",
        processNamePattern: "qoder",
        authKeywords: OutputAnalyzer.qoderAuthKeywords,
        iconName: "hammer"
    )

    public static let allDefaults: [MonitorConfig] = [.codex, .claudeCode, .qoder]
}
