import Foundation

public struct HookBridgePayload: Sendable {
    public let values: [String: JSONValue]

    public init(values: [String: JSONValue]) {
        self.values = values
    }

    public static func parse(_ raw: String) throws -> HookBridgePayload {
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return HookBridgePayload(values: [:])
        }

        let data = Data(raw.utf8)
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        if case .object(let values) = value {
            return HookBridgePayload(values: values)
        }

        return HookBridgePayload(values: ["payload": value])
    }

    public func string(_ key: String) -> String? {
        values[key]?.stringValue
    }

    public func object(_ key: String) -> [String: JSONValue]? {
        values[key]?.objectValue
    }
}

public struct HookBridgeRequest: Encodable, Equatable, Sendable {
    public let id: String
    public let tool: String
    public let type: String
    public let message: String
    public let log: String
    public let options: [HookNotificationOption]
    public let pid: Int32
    public let cwd: String
    public let timestamp: TimeInterval
    public let responsePath: String?
    public let expiresAt: TimeInterval?

    public init(
        payload: HookBridgePayload,
        toolOverride: String?,
        eventId: String,
        responsePath: String?,
        pid: Int32,
        now: Date,
        waitsForDecision: Bool = true
    ) {
        let eventName = payload.string("hook_event_name") ?? "Notification"
        let toolName = toolOverride ?? Self.inferToolName(payload)
        let toolNameFromPayload = payload.string("tool_name")

        self.id = eventId
        self.tool = toolName
        self.type = eventName == "PermissionRequest" ? "auth" : "input"
        self.message = Self.message(for: payload, eventName: eventName, toolName: toolNameFromPayload)
        self.log = Self.log(for: payload, eventName: eventName, toolName: toolNameFromPayload)
        self.options = eventName == "PermissionRequest"
            ? [
                HookNotificationOption(id: "allow", label: "Allow", value: "allow"),
                HookNotificationOption(id: "deny", label: "Deny", value: "deny")
            ]
            : []
        self.pid = pid
        self.cwd = payload.string("cwd") ?? FileManager.default.currentDirectoryPath
        self.timestamp = now.timeIntervalSince1970
        self.responsePath = waitsForDecision ? responsePath : nil
        self.expiresAt = eventName == "PermissionRequest" && !waitsForDecision
            ? now.addingTimeInterval(Self.passThroughTTL).timeIntervalSince1970
            : nil
    }

    private static let passThroughTTL: TimeInterval = 45

    private static func inferToolName(_ payload: HookBridgePayload) -> String {
        if payload.string("agent_type")?.localizedCaseInsensitiveContains("codex") == true {
            return "Codex"
        }
        return "AI Agent"
    }

    private static func message(for payload: HookBridgePayload, eventName: String, toolName: String?) -> String {
        if let message = payload.string("message")?.trimmingCharacters(in: .whitespacesAndNewlines),
           !message.isEmpty {
            return message
        }

        if eventName == "PermissionRequest", let toolName, !toolName.isEmpty {
            return "Permission needed for \(toolName)"
        }

        if let title = payload.string("title")?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            return title
        }

        return "Agent needs attention"
    }

    private static func log(for payload: HookBridgePayload, eventName: String, toolName: String?) -> String {
        if let log = payload.string("log")?.trimmingCharacters(in: .whitespacesAndNewlines),
           !log.isEmpty {
            return log
        }

        if eventName == "PermissionRequest", let toolName, !toolName.isEmpty {
            return truncate("\(toolName): \(previewToolInput(payload))", limit: 500)
        }

        return truncate((try? payload.values.jsonString()) ?? "{}", limit: 500)
    }

    private static func previewToolInput(_ payload: HookBridgePayload) -> String {
        if let toolInput = payload.object("tool_input") {
            for key in ["cmd", "command", "description", "query", "prompt"] {
                if let value = toolInput[key]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !value.isEmpty {
                    return value
                }
            }

            if toolInput.count == 1,
               let value = toolInput.values.first?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return value
            }
        }

        if let toolInput = payload.string("tool_input")?.trimmingCharacters(in: .whitespacesAndNewlines),
           !toolInput.isEmpty {
            return toolInput
        }

        return "permission request"
    }

    private static func truncate(_ value: String, limit: Int) -> String {
        guard value.count > limit else {
            return value
        }
        return String(value.prefix(limit - 3)) + "..."
    }
}

public enum HookBridgeDecision {
    public static func outputJSON(forChoice choice: String) throws -> String {
        guard let normalized = HookBridgeChoice.normalize(choice) else {
            throw HookBridgeError.unsupportedChoice(choice)
        }

        let behavior: String
        let message: String?

        if normalized == "allow" {
            behavior = "allow"
            message = nil
        } else if normalized == "deny" {
            behavior = "deny"
            message = "Denied from CodexReminder"
        } else {
            throw HookBridgeError.unsupportedChoice(choice)
        }

        let output = PermissionRequestOutput(
            hookSpecificOutput: .init(
                hookEventName: "PermissionRequest",
                decision: .init(behavior: behavior, message: message)
            )
        )
        let data = try JSONEncoder.compact.encode(output)
        return String(decoding: data, as: UTF8.self)
    }
}

public enum HookBridgeChoice {
    public static func normalize(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if ["allow", "approve", "yes", "y", "a", "1"].contains(normalized) {
            return "allow"
        }

        if ["deny", "reject", "no", "n", "d", "2"].contains(normalized) {
            return "deny"
        }

        return nil
    }
}

public enum HookBridgeTerminalPrompt {
    public static func text(for request: HookBridgeRequest, timeout: TimeInterval) -> String {
        let timeoutText = timeout > 0 ? "\(Int(timeout))s" : "no timeout"
        let lines = [
            "",
            "CodexReminder authorization request",
            "Tool: \(request.tool)",
            "CWD: \(request.cwd)",
            "Request: \(request.message)",
            "Details: \(request.log)",
            "Options: [a] Allow  [d] Deny",
            "Waiting \(timeoutText) for Touch Bar/menu selection or CLI input, then press Enter.",
            ""
        ]
        return lines.joined(separator: "\n")
    }

    public static func acceptedChoice(fromTerminalInput input: String) -> String? {
        HookBridgeChoice.normalize(input)
    }
}

public enum HookBridgeError: Error, Equatable {
    case unsupportedChoice(String)
}

public enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let value) = self {
            return value
        }
        return nil
    }
}

private struct PermissionRequestOutput: Encodable {
    let hookSpecificOutput: PermissionRequestHookSpecificOutput
}

private struct PermissionRequestHookSpecificOutput: Encodable {
    let hookEventName: String
    let decision: PermissionRequestDecision
}

private struct PermissionRequestDecision: Encodable {
    let behavior: String
    let message: String?

    enum CodingKeys: String, CodingKey {
        case behavior
        case message
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(behavior, forKey: .behavior)
        if let message {
            try container.encode(message, forKey: .message)
        }
    }
}

private extension Dictionary where Key == String, Value == JSONValue {
    func jsonString() throws -> String {
        let data = try JSONEncoder.stable.encode(self)
        return String(decoding: data, as: UTF8.self)
    }
}

private extension JSONEncoder {
    static var compact: JSONEncoder {
        JSONEncoder()
    }

    static var stable: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
