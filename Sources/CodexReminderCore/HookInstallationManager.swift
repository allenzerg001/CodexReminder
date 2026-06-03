import Foundation

public struct HookInstallationManager {
    private let homeDirectory: URL
    private let hookExecutablePath: String
    private let fileManager: FileManager

    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        hookExecutablePath: String,
        fileManager: FileManager = .default
    ) {
        self.homeDirectory = homeDirectory
        self.hookExecutablePath = hookExecutablePath
        self.fileManager = fileManager
    }

    public func install() throws {
        let existingConfigPaths = HookTarget.allCases.compactMap { target -> String? in
            let configURL = homeDirectory.appendingPathComponent(target.relativeConfigPath)
            guard fileManager.fileExists(atPath: configURL.path),
                  var existingRoot = try? readJSONObject(at: configURL) else {
                return nil
            }

            existingRoot.removeCodexReminderHooks(
                hookExecutablePath: hookExecutablePath
            )
            return existingRoot.isEmptyAfterRemovingCodexReminderHooks ? nil : target.relativeConfigPath
        }

        for target in HookTarget.allCases {
            try updateConfig(for: target) { root in
                var root = root
                root.installCodexReminderCommandHook(command: command(for: target), timeout: 600)
                return root
            }
        }

        try HookRuntimeState.setEnabled(
            true,
            homeDirectory: homeDirectory,
            existingConfigPaths: existingConfigPaths
        )
    }

    public func uninstall() throws {
        let existingConfigPaths = HookRuntimeState.existingConfigPaths(homeDirectory: homeDirectory)

        for target in HookTarget.allCases {
            let configURL = homeDirectory.appendingPathComponent(target.relativeConfigPath)
            let updatedRoot = try transformConfig(at: configURL) { root in
                var root = root
                root.removeCodexReminderHooks(
                    hookExecutablePath: hookExecutablePath
                )
                return root
            }

            if !existingConfigPaths.contains(target.relativeConfigPath),
               updatedRoot.isEmptyAfterRemovingCodexReminderHooks {
                try? fileManager.removeItem(at: configURL)
            }
        }

        try HookRuntimeState.setEnabled(false, homeDirectory: homeDirectory)
    }

    private func command(for target: HookTarget) -> String {
        var parts = [
            hookExecutablePath.quotedForShell,
            "--tool",
            target.toolName.quotedForShell
        ]
        if target.suppressesTerminalPrompt {
            parts.append("--no-terminal-prompt")
        }
        return parts.joined(separator: " ")
    }

    private func updateConfig(
        for target: HookTarget,
        transform: (JSONObject) -> JSONObject
    ) throws {
        let configURL = homeDirectory.appendingPathComponent(target.relativeConfigPath)
        _ = try transformConfig(at: configURL, transform: transform)
    }

    @discardableResult
    private func transformConfig(
        at configURL: URL,
        transform: (JSONObject) -> JSONObject
    ) throws -> JSONObject {
        let existingRoot = try readJSONObject(at: configURL)
        let updatedRoot = transform(existingRoot)
        try writeJSONObject(updatedRoot, to: configURL)
        return updatedRoot
    }

    private func readJSONObject(at url: URL) throws -> JSONObject {
        guard fileManager.fileExists(atPath: url.path) else {
            return [:]
        }

        let data = try Data(contentsOf: url)
        guard !data.isEmpty else {
            return [:]
        }

        let value = try JSONSerialization.jsonObject(with: data)
        return value as? JSONObject ?? [:]
    }

    private func writeJSONObject(_ object: JSONObject, to url: URL) throws {
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(to: url, options: .atomic)
    }
}

private typealias JSONObject = [String: Any]

private enum HookTarget: CaseIterable {
    case codex
    case claudeCode
    case qoder

    var relativeConfigPath: String {
        switch self {
        case .codex:
            return ".codex/hooks.json"
        case .claudeCode:
            return ".claude/settings.json"
        case .qoder:
            return ".qoder/settings.json"
        }
    }

    var toolName: String {
        switch self {
        case .codex:
            return "Codex"
        case .claudeCode:
            return "Claude Code"
        case .qoder:
            return "Qoder"
        }
    }

    var suppressesTerminalPrompt: Bool {
        switch self {
        case .claudeCode:
            return true
        case .codex, .qoder:
            return false
        }
    }
}

private extension JSONObject {
    mutating func installCodexReminderCommandHook(command: String, timeout: Int) {
        removeCodexReminderHooks(hookExecutablePath: command)

        var hooksRoot = self["hooks"] as? JSONObject ?? [:]
        var permissionEntries = hooksRoot["PermissionRequest"] as? [Any] ?? []
        permissionEntries.append([
            "matcher": "",
            "hooks": [
                [
                    "type": "command",
                    "command": command,
                    "timeout": timeout
                ] as JSONObject
            ]
        ] as JSONObject)
        hooksRoot["PermissionRequest"] = permissionEntries
        self["hooks"] = hooksRoot
    }

    mutating func removeCodexReminderHooks(hookExecutablePath: String) {
        guard var hooksRoot = self["hooks"] as? JSONObject else {
            return
        }

        for (eventName, value) in hooksRoot {
            guard let entries = value as? [Any] else {
                continue
            }

            let cleanedEntries = entries.compactMap { entry -> Any? in
                guard var entryObject = entry as? JSONObject,
                      let hooks = entryObject["hooks"] as? [Any] else {
                    return entry
                }

                let cleanedHooks = hooks.filter { hook in
                    guard let hookObject = hook as? JSONObject else {
                        return true
                    }

                    if let command = hookObject["command"] as? String,
                       command.isCodexReminderHookCommand(matching: hookExecutablePath) {
                        return false
                    }

                    return true
                }

                guard !cleanedHooks.isEmpty else {
                    return nil
                }

                entryObject["hooks"] = cleanedHooks
                return entryObject
            }

            if cleanedEntries.isEmpty {
                hooksRoot.removeValue(forKey: eventName)
            } else {
                hooksRoot[eventName] = cleanedEntries
            }
        }

        self["hooks"] = hooksRoot
    }

    var isEmptyAfterRemovingCodexReminderHooks: Bool {
        guard count == 1,
              let hooksRoot = self["hooks"] as? JSONObject else {
            return isEmpty
        }

        return hooksRoot.isEmpty
    }
}

private extension String {
    var quotedForShell: String {
        "'\(replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    func isCodexReminderHookCommand(matching hookExecutablePath: String) -> Bool {
        contains("CodexReminderHook") || contains(hookExecutablePath)
    }
}
