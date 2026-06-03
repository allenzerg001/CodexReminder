import Foundation

public struct HookNotificationEvent: Equatable, Sendable, Decodable {
    public let id: String?
    public let tool: String
    public let type: String
    public let message: String
    public let log: String?
    public let options: [HookNotificationOption]
    public let pid: Int32?
    public let cwd: String?
    public let timestamp: TimeInterval
    public let responsePath: String?
    public let expiresAt: TimeInterval?

    public init(
        id: String?,
        tool: String,
        type: String,
        message: String,
        log: String?,
        options: [HookNotificationOption],
        pid: Int32?,
        cwd: String?,
        timestamp: TimeInterval,
        responsePath: String?,
        expiresAt: TimeInterval? = nil
    ) {
        self.id = id
        self.tool = tool
        self.type = type
        self.message = message
        self.log = log
        self.options = options
        self.pid = pid
        self.cwd = cwd
        self.timestamp = timestamp
        self.responsePath = responsePath
        self.expiresAt = expiresAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case tool
        case type
        case message
        case log
        case options
        case pid
        case cwd
        case timestamp
        case responsePath
        case expiresAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.tool = try container.decodeIfPresent(String.self, forKey: .tool) ?? "Unknown"
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? "input"
        self.message = try container.decodeIfPresent(String.self, forKey: .message) ?? "Needs attention"
        self.log = try container.decodeIfPresent(String.self, forKey: .log)
        self.options = try container.decodeIfPresent([HookNotificationOption].self, forKey: .options) ?? []
        self.pid = try container.decodeIfPresent(Int32.self, forKey: .pid)
        self.cwd = try container.decodeIfPresent(String.self, forKey: .cwd)
        self.timestamp = try container.decodeIfPresent(TimeInterval.self, forKey: .timestamp) ?? Date().timeIntervalSince1970
        self.responsePath = try container.decodeIfPresent(String.self, forKey: .responsePath)
        self.expiresAt = try container.decodeIfPresent(TimeInterval.self, forKey: .expiresAt)
    }
}

public struct HookNotificationOption: Equatable, Sendable, Codable {
    public let id: String?
    public let label: String?
    public let value: String?

    public init(id: String?, label: String?, value: String?) {
        self.id = id
        self.label = label
        self.value = value
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case label
        case title
        case value
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let title = try? container.decode(String.self) {
            self.id = title
            self.label = title
            self.value = title
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.label = try container.decodeIfPresent(String.self, forKey: .label)
            ?? container.decodeIfPresent(String.self, forKey: .title)
        self.value = try container.decodeIfPresent(String.self, forKey: .value)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(label, forKey: .label)
        try container.encodeIfPresent(value, forKey: .value)
    }
}

public enum HookNotificationParser {
    public static let defaultTTL: TimeInterval = 300

    public static func parse(
        data: Data,
        requestPath: String,
        now: Date = Date(),
        ttl: TimeInterval = defaultTTL
    ) -> ToolInfo? {
        guard let event = try? JSONDecoder().decode(HookNotificationEvent.self, from: data) else {
            return nil
        }

        let created = Date(timeIntervalSince1970: event.timestamp)
        if let expiresAt = event.expiresAt {
            guard now.timeIntervalSince1970 <= expiresAt else {
                return nil
            }
        } else if now.timeIntervalSince(created) > ttl {
            return nil
        }

        let toolName = event.tool.isEmpty ? "Unknown" : event.tool
        let message = event.message.isEmpty ? "Needs attention" : event.message
        let status: ToolStatus = event.type == "auth"
            ? .waitingForAuth(message: message)
            : .waitingForInput(message: message)

        return ToolInfo(
            id: stableId(for: event, requestPath: requestPath),
            name: toolName,
            icon: iconName(for: toolName),
            status: status,
            lastUpdated: created,
            workingDirectory: event.cwd,
            terminalApp: nil,
            pid: event.pid,
            log: event.log,
            choices: choices(from: event.options),
            requestPath: requestPath,
            responsePath: event.responsePath
        )
    }

    public static func iconName(for toolName: String) -> String {
        switch toolName.lowercased() {
        case let name where name.contains("codex"):
            return "brain.head.profile"
        case let name where name.contains("claude"):
            return "sparkle"
        case let name where name.contains("qoder"):
            return "hammer"
        default:
            return "questionmark.circle"
        }
    }

    private static func stableId(for event: HookNotificationEvent, requestPath: String) -> String {
        if let id = event.id, !id.isEmpty {
            return "hook-\(id)"
        }

        let filename = URL(fileURLWithPath: requestPath).lastPathComponent
        return "hook-\(filename)"
    }

    private static func choices(from options: [HookNotificationOption]) -> [ToolChoice] {
        options.enumerated().compactMap { index, option in
            let title = option.label ?? option.value ?? option.id
            guard let title, !title.isEmpty else {
                return nil
            }

            let value = option.value ?? option.id ?? title
            let id = option.id ?? value
            return ToolChoice(id: id.isEmpty ? "choice-\(index)" : id, title: title, value: value)
        }
    }
}
