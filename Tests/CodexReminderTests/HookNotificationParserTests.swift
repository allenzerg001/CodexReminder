import XCTest
@testable import CodexReminderCore

final class HookNotificationParserTests: XCTestCase {

    func testParsesAuthEventWithChoicesAndLog() throws {
        let timestamp: TimeInterval = 1_800_000_000
        let json = """
        {
            "id": "abc123",
            "tool": "Claude Code",
            "type": "auth",
            "message": "Permission needed",
            "log": "Claude wants to run npm test",
            "options": [
                { "id": "allow", "label": "Allow", "value": "allow" },
                { "id": "deny", "label": "Deny", "value": "deny" }
            ],
            "pid": 123,
            "cwd": "/tmp/project",
            "timestamp": \(timestamp),
            "responsePath": "/tmp/codexreminder-response.json"
        }
        """

        let tool = HookNotificationParser.parse(
            data: try XCTUnwrap(json.data(using: .utf8)),
            requestPath: "/tmp/request.json",
            now: Date(timeIntervalSince1970: timestamp + 1)
        )

        let parsed = try XCTUnwrap(tool)
        XCTAssertEqual(parsed.id, "hook-abc123")
        XCTAssertEqual(parsed.name, "Claude Code")
        XCTAssertEqual(parsed.icon, "sparkle")
        XCTAssertEqual(parsed.status, .waitingForAuth(message: "Permission needed"))
        XCTAssertEqual(parsed.log, "Claude wants to run npm test")
        XCTAssertEqual(parsed.choices, [
            ToolChoice(id: "allow", title: "Allow", value: "allow"),
            ToolChoice(id: "deny", title: "Deny", value: "deny")
        ])
        XCTAssertEqual(parsed.pid, 123)
        XCTAssertEqual(parsed.workingDirectory, "/tmp/project")
        XCTAssertEqual(parsed.requestPath, "/tmp/request.json")
        XCTAssertEqual(parsed.responsePath, "/tmp/codexreminder-response.json")
    }

    func testParsesStringChoicesAndFallsBackToFilenameId() throws {
        let timestamp: TimeInterval = 1_800_000_000
        let json = """
        {
            "tool": "Codex",
            "type": "input",
            "message": "Choose an option",
            "options": ["Approve", "Deny"],
            "timestamp": \(timestamp)
        }
        """

        let tool = HookNotificationParser.parse(
            data: try XCTUnwrap(json.data(using: .utf8)),
            requestPath: "/tmp/codex_1.json",
            now: Date(timeIntervalSince1970: timestamp + 1)
        )

        let parsed = try XCTUnwrap(tool)
        XCTAssertEqual(parsed.id, "hook-codex_1.json")
        XCTAssertEqual(parsed.icon, "brain.head.profile")
        XCTAssertEqual(parsed.status, .waitingForInput(message: "Choose an option"))
        XCTAssertEqual(parsed.choices, [
            ToolChoice(id: "Approve", title: "Approve", value: "Approve"),
            ToolChoice(id: "Deny", title: "Deny", value: "Deny")
        ])
    }

    func testIgnoresExpiredEvents() throws {
        let timestamp: TimeInterval = 1_800_000_000
        let json = """
        {
            "tool": "Codex",
            "message": "Old request",
            "timestamp": \(timestamp)
        }
        """

        let tool = HookNotificationParser.parse(
            data: try XCTUnwrap(json.data(using: .utf8)),
            requestPath: "/tmp/old.json",
            now: Date(timeIntervalSince1970: timestamp + HookNotificationParser.defaultTTL + 1)
        )

        XCTAssertNil(tool)
    }

    func testIgnoresEventsPastExplicitExpiration() throws {
        let timestamp: TimeInterval = 1_800_000_000
        let json = """
        {
            "tool": "Codex",
            "type": "auth",
            "message": "Permission needed",
            "timestamp": \(timestamp),
            "expiresAt": \(timestamp + 45)
        }
        """

        let tool = HookNotificationParser.parse(
            data: try XCTUnwrap(json.data(using: .utf8)),
            requestPath: "/tmp/expired-pass-through.json",
            now: Date(timeIntervalSince1970: timestamp + 46)
        )

        XCTAssertNil(tool)
    }

    func testDisplayLogFallsBackToMessage() {
        let tool = ToolInfo(
            id: "t1",
            name: "Codex",
            icon: "brain",
            status: .waitingForAuth(message: "Approve command"),
            lastUpdated: Date(),
            log: "  "
        )

        XCTAssertEqual(tool.displayLog, "Approve command")
    }
}
