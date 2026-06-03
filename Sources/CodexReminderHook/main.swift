import Foundation
import CodexReminderCore
import Darwin

private let pollInterval: TimeInterval = 0.2

struct Arguments {
    var tool: String?
    var timeout: TimeInterval = ProcessInfo.processInfo.environment["CODEX_REMINDER_TIMEOUT"]
        .flatMap(TimeInterval.init) ?? 300
    var terminalPromptEnabled = true
    var waitForDecision = false
}

func parseArguments(_ values: [String]) -> Arguments {
    var arguments = Arguments()
    var index = 0

    while index < values.count {
        switch values[index] {
        case "--tool" where index + 1 < values.count:
            arguments.tool = values[index + 1]
            index += 2
        case "--timeout" where index + 1 < values.count:
            if let timeout = TimeInterval(values[index + 1]) {
                arguments.timeout = timeout
            }
            index += 2
        case "--no-terminal-prompt":
            arguments.terminalPromptEnabled = false
            index += 1
        case "--wait-for-decision":
            arguments.waitForDecision = true
            index += 1
        default:
            index += 1
        }
    }

    return arguments
}

func readStandardInput() -> String {
    let data = FileHandle.standardInput.readDataToEndOfFile()
    return String(decoding: data, as: UTF8.self)
}

func makeEventId(toolName: String, eventName: String, payload: HookBridgePayload) -> String {
    let prefix = toolName.lowercased()
        .map { character in character.isLetter || character.isNumber || character == "." || character == "_" || character == "-" ? character : "-" }
        .reduce("") { $0 + String($1) }
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    let safePrefix = prefix.isEmpty ? "agent" : prefix
    let source = [
        toolName,
        eventName,
        payload.string("session_id") ?? "",
        payload.string("turn_id") ?? "",
        payload.string("tool_name") ?? "",
        String(Date().timeIntervalSince1970)
    ].joined(separator: "|")
    return "\(safePrefix)-\(source.fnv1a64Hex.prefix(16))"
}

func writeJSONAtomic<T: Encodable>(_ value: T, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let temporaryURL = url.appendingPathExtension("tmp")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    try encoder.encode(value).write(to: temporaryURL, options: .atomic)
    _ = try FileManager.default.replaceItemAt(url, withItemAt: temporaryURL)
}

func waitForChoice(responseURL: URL, timeout: TimeInterval) -> String? {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if let choice = readChoice(from: responseURL) {
            return choice
        }
        Thread.sleep(forTimeInterval: pollInterval)
    }
    return nil
}

func readChoice(from responseURL: URL) -> String? {
    if let data = try? Data(contentsOf: responseURL),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let value = json["value"] as? String,
           let choice = HookBridgeChoice.normalize(value) {
            return choice
        }
        if let choiceId = json["choiceId"] as? String,
           let choice = HookBridgeChoice.normalize(choiceId) {
            return choice
        }
    }

    return nil
}

func openTerminalDescriptor() -> Int32? {
    let descriptor = open("/dev/tty", O_RDWR | O_NONBLOCK)
    guard descriptor >= 0 else {
        return nil
    }
    return descriptor
}

func writeTerminalPrompt(_ prompt: String, terminalDescriptor: Int32?) {
    if let terminalDescriptor {
        prompt.withCString { pointer in
            _ = Darwin.write(terminalDescriptor, pointer, strlen(pointer))
        }
        return
    }

    fputs(prompt, stderr)
}

func readTerminalChoice(
    terminalDescriptor: Int32?,
    pendingInput: inout String
) -> String? {
    guard let terminalDescriptor else {
        return nil
    }

    var buffer = [UInt8](repeating: 0, count: 128)

    while true {
        let count = Darwin.read(terminalDescriptor, &buffer, buffer.count)
        if count > 0 {
            pendingInput += String(decoding: buffer.prefix(count), as: UTF8.self)
            continue
        }

        break
    }

    guard pendingInput.contains("\n") || pendingInput.contains("\r") else {
        return nil
    }

    let input = pendingInput
    pendingInput = ""

    if let choice = HookBridgeTerminalPrompt.acceptedChoice(fromTerminalInput: input) {
        return choice
    }

    let retry = "Unknown choice. Type 'a' to allow or 'd' to deny, then press Enter.\n"
    retry.withCString { pointer in
        _ = Darwin.write(terminalDescriptor, pointer, strlen(pointer))
    }

    return nil
}

func waitForChoice(responseURL: URL, timeout: TimeInterval, terminalDescriptor: Int32?) -> String? {
    let deadline = Date().addingTimeInterval(timeout)
    var pendingTerminalInput = ""

    while Date() < deadline {
        if let choice = readTerminalChoice(
            terminalDescriptor: terminalDescriptor,
            pendingInput: &pendingTerminalInput
        ) {
            return choice
        }

        if let choice = readChoice(from: responseURL) {
            return choice
        }

        Thread.sleep(forTimeInterval: pollInterval)
    }

    return readTerminalChoice(terminalDescriptor: terminalDescriptor, pendingInput: &pendingTerminalInput)
}

let arguments = parseArguments(Array(CommandLine.arguments.dropFirst()))
let rawPayload = readStandardInput()
let payload = (try? HookBridgePayload.parse(rawPayload)) ?? HookBridgePayload(values: [:])
let eventName = payload.string("hook_event_name") ?? "Notification"
let toolName = arguments.tool ?? (payload.string("agent_type")?.localizedCaseInsensitiveContains("codex") == true ? "Codex" : "AI Agent")
let basePath = ProcessInfo.processInfo.environment["CODEX_REMINDER_HOME"]
    ?? "\(FileManager.default.homeDirectoryForCurrentUser.path)/.codexreminder"
let baseURL = URL(fileURLWithPath: basePath)
let homeDirectory = baseURL.deletingLastPathComponent()

guard HookRuntimeState.isEnabled(homeDirectory: homeDirectory) else {
    exit(0)
}

let eventId = makeEventId(toolName: toolName, eventName: eventName, payload: payload)
let requestURL = baseURL.appendingPathComponent("notifications").appendingPathComponent("\(eventId).json")
let responseURL = baseURL.appendingPathComponent("responses").appendingPathComponent("\(eventId).json")

let request = HookBridgeRequest(
    payload: payload,
    toolOverride: arguments.tool,
    eventId: eventId,
    responsePath: arguments.waitForDecision ? responseURL.path : nil,
    pid: Int32(ProcessInfo.processInfo.processIdentifier),
    now: Date(),
    waitsForDecision: arguments.waitForDecision
)

do {
    try writeJSONAtomic(request, to: requestURL)
} catch {
    fputs("CodexReminderHook failed to write request: \(error.localizedDescription)\n", stderr)
    exit(1)
}

guard eventName == "PermissionRequest" else {
    exit(0)
}

guard arguments.waitForDecision else {
    exit(0)
}

let terminalDescriptor = arguments.terminalPromptEnabled ? openTerminalDescriptor() : nil
defer {
    if let terminalDescriptor {
        close(terminalDescriptor)
    }
}
if arguments.terminalPromptEnabled {
    writeTerminalPrompt(
        HookBridgeTerminalPrompt.text(for: request, timeout: arguments.timeout),
        terminalDescriptor: terminalDescriptor
    )
}

let choice = waitForChoice(responseURL: responseURL, timeout: arguments.timeout, terminalDescriptor: terminalDescriptor)
try? FileManager.default.removeItem(at: requestURL)
try? FileManager.default.removeItem(at: responseURL)

guard let choice else {
    exit(0)
}

do {
    print(try HookBridgeDecision.outputJSON(forChoice: choice))
} catch {
    exit(0)
}

private extension String {
    var fnv1a64Hex: String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }
}
