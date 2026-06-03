import XCTest
@testable import CodexReminderCore

final class HookBridgeTests: XCTestCase {
    func testBuildsCodexPermissionRequest() throws {
        let rawPayload = """
        {
            "hook_event_name": "PermissionRequest",
            "agent_type": "codex",
            "tool_name": "shell",
            "tool_input": { "cmd": "swift test" },
            "cwd": "/tmp/project",
            "session_id": "session-1",
            "turn_id": "turn-1"
        }
        """

        let payload = try HookBridgePayload.parse(rawPayload)
        let request = HookBridgeRequest(
            payload: payload,
            toolOverride: "Codex",
            eventId: "codex-test",
            responsePath: "/tmp/response.json",
            pid: 123,
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )

        XCTAssertEqual(request.id, "codex-test")
        XCTAssertEqual(request.tool, "Codex")
        XCTAssertEqual(request.type, "auth")
        XCTAssertEqual(request.message, "Permission needed for shell")
        XCTAssertEqual(request.log, "shell: swift test")
        XCTAssertEqual(request.options, [
            HookNotificationOption(id: "allow", label: "Allow", value: "allow"),
            HookNotificationOption(id: "deny", label: "Deny", value: "deny")
        ])
        XCTAssertEqual(request.pid, 123)
        XCTAssertEqual(request.cwd, "/tmp/project")
        XCTAssertEqual(request.timestamp, 1_800_000_000)
        XCTAssertEqual(request.responsePath, "/tmp/response.json")
    }

    func testDecisionOutputForAllowChoice() throws {
        let output = try HookBridgeDecision.outputJSON(forChoice: "allow")
        let payload = try JSONDecoder().decode(PermissionRequestOutputAssertion.self, from: Data(output.utf8))

        XCTAssertEqual(payload.hookSpecificOutput.hookEventName, "PermissionRequest")
        XCTAssertEqual(payload.hookSpecificOutput.decision.behavior, "allow")
        XCTAssertNil(payload.hookSpecificOutput.decision.message)
    }

    func testDecisionOutputForDenyChoice() throws {
        let output = try HookBridgeDecision.outputJSON(forChoice: "deny")
        let payload = try JSONDecoder().decode(PermissionRequestOutputAssertion.self, from: Data(output.utf8))

        XCTAssertEqual(payload.hookSpecificOutput.hookEventName, "PermissionRequest")
        XCTAssertEqual(payload.hookSpecificOutput.decision.behavior, "deny")
        XCTAssertEqual(payload.hookSpecificOutput.decision.message, "Denied from CodexReminder")
    }

    func testDecisionOutputNormalizesCliShortcutChoices() throws {
        let allowOutput = try HookBridgeDecision.outputJSON(forChoice: "a\n")
        let denyOutput = try HookBridgeDecision.outputJSON(forChoice: "2")
        let allowPayload = try JSONDecoder().decode(PermissionRequestOutputAssertion.self, from: Data(allowOutput.utf8))
        let denyPayload = try JSONDecoder().decode(PermissionRequestOutputAssertion.self, from: Data(denyOutput.utf8))

        XCTAssertEqual(allowPayload.hookSpecificOutput.decision.behavior, "allow")
        XCTAssertEqual(denyPayload.hookSpecificOutput.decision.behavior, "deny")
    }

    func testTerminalPromptShowsReadableRequestAndOptions() throws {
        let rawPayload = """
        {
            "hook_event_name": "PermissionRequest",
            "agent_type": "codex",
            "tool_name": "shell",
            "tool_input": { "cmd": "swift test" },
            "cwd": "/tmp/project"
        }
        """

        let request = HookBridgeRequest(
            payload: try HookBridgePayload.parse(rawPayload),
            toolOverride: "Codex",
            eventId: "codex-test",
            responsePath: "/tmp/response.json",
            pid: 123,
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )

        let prompt = HookBridgeTerminalPrompt.text(for: request, timeout: 600)

        XCTAssertTrue(prompt.contains("CodexReminder authorization request"))
        XCTAssertTrue(prompt.contains("Tool: Codex"))
        XCTAssertTrue(prompt.contains("CWD: /tmp/project"))
        XCTAssertTrue(prompt.contains("Request: Permission needed for shell"))
        XCTAssertTrue(prompt.contains("Details: shell: swift test"))
        XCTAssertTrue(prompt.contains("Options: [a] Allow  [d] Deny"))
        XCTAssertTrue(prompt.contains("Waiting 600s"))
    }
}

private struct PermissionRequestOutputAssertion: Decodable {
    let hookSpecificOutput: HookSpecificOutput

    struct HookSpecificOutput: Decodable {
        let hookEventName: String
        let decision: Decision
    }

    struct Decision: Decodable {
        let behavior: String
        let message: String?
    }
}
