import XCTest

final class HookExecutableTests: XCTestCase {
    private var temporaryHome: URL!

    override func setUpWithError() throws {
        temporaryHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("codexreminder-hook-executable-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temporaryHome, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryHome)
        temporaryHome = nil
    }

    func testHookExecutableExitsQuietlyWhenRuntimeStateIsDisabled() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: try hookExecutablePath())
        process.arguments = ["--tool", "Codex", "--timeout", "1"]
        process.environment = [
            "CODEX_REMINDER_HOME": temporaryHome.appendingPathComponent(".codexreminder").path
        ]

        let input = Pipe()
        let output = Pipe()
        let error = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = error

        try process.run()
        input.fileHandleForWriting.write(
            #"{"hook_event_name":"PermissionRequest","agent_type":"codex","tool_name":"shell"}"#
                .data(using: .utf8)!
        )
        input.fileHandleForWriting.closeFile()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertEqual(String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self), "")
        XCTAssertEqual(String(decoding: error.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self), "")
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: temporaryHome.appendingPathComponent(".codexreminder/notifications").path
            )
        )
    }

    func testClaudeCodePermissionRequestWritesNotificationAndLetsCliShowOriginalDialog() throws {
        let codexReminderHome = temporaryHome.appendingPathComponent(".codexreminder")
        let stateURL = temporaryHome.appendingPathComponent(".codexreminder/hook-state.json")
        try FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try #"{"enabled":true}"#.write(to: stateURL, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: try hookExecutablePath())
        process.arguments = ["--tool", "Claude Code", "--timeout", "5", "--no-terminal-prompt"]
        process.environment = [
            "CODEX_REMINDER_HOME": codexReminderHome.path
        ]

        let input = Pipe()
        let output = Pipe()
        let error = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = error

        try process.run()
        input.fileHandleForWriting.write(
            """
            {
              "hook_event_name": "PermissionRequest",
              "session_id": "session-claude",
              "tool_name": "Bash",
              "tool_input": { "command": "swift test" },
              "cwd": "/tmp/project"
            }
            """.data(using: .utf8)!
        )
        input.fileHandleForWriting.closeFile()

        let requestURL = try waitForSingleNotification(in: codexReminderHome)
        let request = try readObject(at: requestURL)
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertEqual(String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self), "")
        XCTAssertEqual(String(decoding: error.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self), "")
        XCTAssertTrue(FileManager.default.fileExists(atPath: requestURL.path))
        XCTAssertEqual(request["tool"] as? String, "Claude Code")
        XCTAssertEqual(request["type"] as? String, "auth")
        XCTAssertEqual(request["message"] as? String, "Permission needed for Bash")
        XCTAssertEqual(request["log"] as? String, "Bash: swift test")
        XCTAssertEqual(request["cwd"] as? String, "/tmp/project")
        XCTAssertNil(request["responsePath"] as? String)
        XCTAssertNotNil(request["expiresAt"] as? Double)
        let options = try XCTUnwrap(request["options"] as? [[String: Any]])
        XCTAssertEqual(options.compactMap { $0["value"] as? String }, ["allow", "deny"])
    }

    func testClaudeCodePermissionRequestCanWaitForExplicitDecision() throws {
        let codexReminderHome = temporaryHome.appendingPathComponent(".codexreminder")
        let stateURL = temporaryHome.appendingPathComponent(".codexreminder/hook-state.json")
        try FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try #"{"enabled":true}"#.write(to: stateURL, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: try hookExecutablePath())
        process.arguments = [
            "--tool",
            "Claude Code",
            "--timeout",
            "5",
            "--no-terminal-prompt",
            "--wait-for-decision"
        ]
        process.environment = [
            "CODEX_REMINDER_HOME": codexReminderHome.path
        ]

        let input = Pipe()
        let output = Pipe()
        let error = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = error

        try process.run()
        input.fileHandleForWriting.write(
            """
            {
              "hook_event_name": "PermissionRequest",
              "session_id": "session-claude",
              "tool_name": "Bash",
              "tool_input": { "command": "swift test" },
              "cwd": "/tmp/project"
            }
            """.data(using: .utf8)!
        )
        input.fileHandleForWriting.closeFile()

        let requestURL = try waitForSingleNotification(in: codexReminderHome)
        let request = try readObject(at: requestURL)
        let responsePath = try XCTUnwrap(request["responsePath"] as? String)
        let responseURL = URL(fileURLWithPath: responsePath)
        try FileManager.default.createDirectory(
            at: responseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try #"{"value":"allow"}"#.write(
            to: responseURL,
            atomically: true,
            encoding: .utf8
        )

        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertEqual(String(decoding: error.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self), "")
        XCTAssertFalse(FileManager.default.fileExists(atPath: requestURL.path))

        let stdout = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        XCTAssertTrue(stdout.contains(#""hookEventName":"PermissionRequest""#))
        XCTAssertTrue(stdout.contains(#""behavior":"allow""#))
        XCTAssertEqual(request["tool"] as? String, "Claude Code")
        XCTAssertEqual(request["type"] as? String, "auth")
        XCTAssertEqual(request["message"] as? String, "Permission needed for Bash")
        XCTAssertEqual(request["log"] as? String, "Bash: swift test")
        XCTAssertEqual(request["cwd"] as? String, "/tmp/project")
    }

    private func waitForSingleNotification(in codexReminderHome: URL) throws -> URL {
        let notificationsURL = codexReminderHome.appendingPathComponent("notifications")
        let deadline = Date().addingTimeInterval(3)

        while Date() < deadline {
            let files = (try? FileManager.default.contentsOfDirectory(
                at: notificationsURL,
                includingPropertiesForKeys: nil
            )) ?? []
            let jsonFiles = files.filter { $0.pathExtension == "json" }
            if let first = jsonFiles.first {
                return first
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        XCTFail("Timed out waiting for hook notification")
        throw CocoaError(.fileNoSuchFile)
    }

    private func readObject(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        let value = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(value as? [String: Any])
    }

    private func hookExecutablePath() throws -> String {
        let productsDirectory = URL(fileURLWithPath: Bundle.main.bundlePath)
            .deletingLastPathComponent()
        let candidates = [
            productsDirectory.appendingPathComponent("CodexReminderHook"),
            productsDirectory
                .deletingLastPathComponent()
                .appendingPathComponent("debug/CodexReminderHook"),
            productsDirectory
                .deletingLastPathComponent()
                .appendingPathComponent("release/CodexReminderHook")
        ]

        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate.path) {
            return candidate.path
        }

        let buildURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build")
        if let enumerator = FileManager.default.enumerator(
            at: buildURL,
            includingPropertiesForKeys: nil
        ) {
            for case let candidate as URL in enumerator
                where candidate.lastPathComponent == "CodexReminderHook"
                    && FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate.path
            }
        }

        throw XCTSkip("CodexReminderHook executable not found in test products")
    }
}
