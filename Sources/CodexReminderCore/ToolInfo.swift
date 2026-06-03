import Foundation

public struct ToolInfo: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let icon: String
    public var status: ToolStatus
    public var lastUpdated: Date
    public var workingDirectory: String?
    public var terminalApp: String?
    public var pid: Int32?
    public var log: String?
    public var choices: [ToolChoice]
    public var requestPath: String?
    public var responsePath: String?

    public init(
        id: String,
        name: String,
        icon: String,
        status: ToolStatus,
        lastUpdated: Date,
        workingDirectory: String? = nil,
        terminalApp: String? = nil,
        pid: Int32? = nil,
        log: String? = nil,
        choices: [ToolChoice] = [],
        requestPath: String? = nil,
        responsePath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.status = status
        self.lastUpdated = lastUpdated
        self.workingDirectory = workingDirectory
        self.terminalApp = terminalApp
        self.pid = pid
        self.log = log
        self.choices = choices
        self.requestPath = requestPath
        self.responsePath = responsePath
    }

    public var displayMessage: String {
        status.displayMessage
    }

    public var displayLog: String {
        let trimmed = log?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed! : displayMessage
    }
}
