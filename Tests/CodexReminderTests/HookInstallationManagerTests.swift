import XCTest
@testable import CodexReminderCore

final class HookInstallationManagerTests: XCTestCase {
    private var temporaryHome: URL!

    override func setUpWithError() throws {
        temporaryHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("codexreminder-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temporaryHome, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryHome)
        temporaryHome = nil
    }

    func testInstallAddsCodexReminderHooksToSupportedToolConfigs() throws {
        let manager = HookInstallationManager(
            homeDirectory: temporaryHome,
            hookExecutablePath: "/Applications/CodexReminder.app/Contents/MacOS/CodexReminderHook"
        )

        try manager.install()

        let codexConfig = try readObject(at: temporaryHome.appendingPathComponent(".codex/hooks.json"))
        let claudeConfig = try readObject(at: temporaryHome.appendingPathComponent(".claude/settings.json"))
        let qoderConfig = try readObject(at: temporaryHome.appendingPathComponent(".qoder/settings.json"))
        let enabledConfig = try readObject(at: temporaryHome.appendingPathComponent(".codexreminder/hook-state.json"))

        XCTAssertTrue(containsCodexReminderCommand(in: codexConfig, tool: "Codex"))
        XCTAssertTrue(containsCodexReminderCommand(in: claudeConfig, tool: "Claude Code"))
        XCTAssertTrue(containsCommand(in: claudeConfig, commandFragment: "--no-terminal-prompt"))
        XCTAssertFalse(containsCommand(in: codexConfig, commandFragment: "--wait-for-decision"))
        XCTAssertFalse(containsCommand(in: claudeConfig, commandFragment: "--wait-for-decision"))
        XCTAssertFalse(containsCommand(in: qoderConfig, commandFragment: "--wait-for-decision"))
        XCTAssertTrue(containsCodexReminderCommand(in: qoderConfig, tool: "Qoder"))
        XCTAssertEqual(enabledConfig["enabled"] as? Bool, true)
    }

    func testInstallDoesNotRemoveExistingClawdClaudeHTTPPermissionHook() throws {
        let claudeConfigURL = temporaryHome.appendingPathComponent(".claude/settings.json")
        try FileManager.default.createDirectory(at: claudeConfigURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        {
          "hooks": {
            "PermissionRequest": [
              {
                "matcher": "",
                "hooks": [
                  {
                    "type": "http",
                    "url": "http://127.0.0.1:23333/permission",
                    "timeout": 600
                  }
                ]
              }
            ]
          }
        }
        """.write(to: claudeConfigURL, atomically: true, encoding: .utf8)

        let manager = HookInstallationManager(
            homeDirectory: temporaryHome,
            hookExecutablePath: "/Applications/CodexReminder.app/Contents/MacOS/CodexReminderHook"
        )

        try manager.install()

        let claudeConfig = try readObject(at: claudeConfigURL)
        XCTAssertTrue(containsHTTPHook(in: claudeConfig, url: "http://127.0.0.1:23333/permission"))
        XCTAssertTrue(containsCodexReminderCommand(in: claudeConfig, tool: "Claude Code"))

        try manager.uninstall()

        let uninstalledClaudeConfig = try readObject(at: claudeConfigURL)
        XCTAssertTrue(containsHTTPHook(in: uninstalledClaudeConfig, url: "http://127.0.0.1:23333/permission"))
        XCTAssertFalse(containsCodexReminderCommand(in: uninstalledClaudeConfig, tool: "Claude Code"))
    }

    func testUninstallRemovesOnlyCodexReminderHooksAndPreservesExistingHooks() throws {
        let codexConfigURL = temporaryHome.appendingPathComponent(".codex/hooks.json")
        try FileManager.default.createDirectory(at: codexConfigURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        {
          "hooks": {
            "PermissionRequest": [
              {
                "matcher": "",
                "hooks": [
                  {
                    "type": "command",
                    "command": "existing-hook",
                    "timeout": 30
                  }
                ]
              }
            ]
          }
        }
        """.write(to: codexConfigURL, atomically: true, encoding: .utf8)

        let manager = HookInstallationManager(
            homeDirectory: temporaryHome,
            hookExecutablePath: "/Applications/CodexReminder.app/Contents/MacOS/CodexReminderHook"
        )

        try manager.install()
        try manager.uninstall()

        let codexConfig = try readObject(at: codexConfigURL)
        let enabledConfig = try readObject(at: temporaryHome.appendingPathComponent(".codexreminder/hook-state.json"))

        XCTAssertFalse(containsCodexReminderCommand(in: codexConfig, tool: "Codex"))
        XCTAssertTrue(containsCommand(in: codexConfig, commandFragment: "existing-hook"))
        XCTAssertEqual(enabledConfig["enabled"] as? Bool, false)
    }

    func testUninstallRemovesConfigFilesCreatedOnlyForCodexReminderHooks() throws {
        let manager = HookInstallationManager(
            homeDirectory: temporaryHome,
            hookExecutablePath: "/Applications/CodexReminder.app/Contents/MacOS/CodexReminderHook"
        )
        let qoderConfigURL = temporaryHome.appendingPathComponent(".qoder/settings.json")

        try manager.install()
        XCTAssertTrue(FileManager.default.fileExists(atPath: qoderConfigURL.path))

        try manager.uninstall()

        XCTAssertFalse(FileManager.default.fileExists(atPath: qoderConfigURL.path))
    }

    func testInstallDoesNotTreatStaleCodexReminderOnlyConfigAsUserConfig() throws {
        let manager = HookInstallationManager(
            homeDirectory: temporaryHome,
            hookExecutablePath: "/Applications/CodexReminder.app/Contents/MacOS/CodexReminderHook"
        )
        let qoderConfigURL = temporaryHome.appendingPathComponent(".qoder/settings.json")

        try manager.install()

        let secondLaunchManager = HookInstallationManager(
            homeDirectory: temporaryHome,
            hookExecutablePath: "/Applications/CodexReminder.app/Contents/MacOS/CodexReminderHook"
        )
        try secondLaunchManager.install()
        try secondLaunchManager.uninstall()

        XCTAssertFalse(FileManager.default.fileExists(atPath: qoderConfigURL.path))
    }

    func testHookStateReportsDisabledWhenStateFileIsMissingOrDisabled() throws {
        let stateURL = temporaryHome.appendingPathComponent(".codexreminder/hook-state.json")

        XCTAssertFalse(HookRuntimeState.isEnabled(homeDirectory: temporaryHome))

        try FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try #"{"enabled":false}"#.write(to: stateURL, atomically: true, encoding: .utf8)

        XCTAssertFalse(HookRuntimeState.isEnabled(homeDirectory: temporaryHome))

        try #"{"enabled":true}"#.write(to: stateURL, atomically: true, encoding: .utf8)

        XCTAssertTrue(HookRuntimeState.isEnabled(homeDirectory: temporaryHome))
    }

    func testHookStateReportsDisabledWhenRecordedAppProcessIsNotRunning() throws {
        let stateURL = temporaryHome.appendingPathComponent(".codexreminder/hook-state.json")
        try FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try #"{"enabled":true,"appPid":999999}"#.write(to: stateURL, atomically: true, encoding: .utf8)

        XCTAssertFalse(HookRuntimeState.isEnabled(homeDirectory: temporaryHome))
    }

    func testHookStateReportsDisabledWhenRecordedProcessPathDoesNotMatch() throws {
        let stateURL = temporaryHome.appendingPathComponent(".codexreminder/hook-state.json")
        try FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        {
          "enabled": true,
          "appPid": \(ProcessInfo.processInfo.processIdentifier),
          "appExecutablePath": "/tmp/not-codexreminder"
        }
        """.write(to: stateURL, atomically: true, encoding: .utf8)

        XCTAssertFalse(HookRuntimeState.isEnabled(homeDirectory: temporaryHome))
    }

    private func readObject(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        let value = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(value as? [String: Any])
    }

    private func containsCodexReminderCommand(in object: [String: Any], tool: String) -> Bool {
        containsCommand(in: object, commandFragment: "CodexReminderHook")
            && containsCommand(in: object, commandFragment: "--tool \(tool.quotedForShell)")
    }

    private func containsHTTPHook(in value: Any, url: String) -> Bool {
        if let object = value as? [String: Any] {
            if object["type"] as? String == "http", object["url"] as? String == url {
                return true
            }
            return object.values.contains { containsHTTPHook(in: $0, url: url) }
        }

        if let array = value as? [Any] {
            return array.contains { containsHTTPHook(in: $0, url: url) }
        }

        return false
    }

    private func containsCommand(in value: Any, commandFragment: String) -> Bool {
        if let object = value as? [String: Any] {
            if let command = object["command"] as? String, command.contains(commandFragment) {
                return true
            }
            return object.values.contains { containsCommand(in: $0, commandFragment: commandFragment) }
        }

        if let array = value as? [Any] {
            return array.contains { containsCommand(in: $0, commandFragment: commandFragment) }
        }

        return false
    }
}

private extension String {
    var quotedForShell: String {
        "'\(replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
