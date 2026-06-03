import XCTest
@testable import CodexReminderCore

final class ToolInfoTests: XCTestCase {

    func testToolInfoDisplayMessageDelegates() {
        let tool = ToolInfo(
            id: "test-1",
            name: "Test",
            icon: "gear",
            status: .waitingForAuth(message: "Please approve"),
            lastUpdated: Date()
        )
        XCTAssertEqual(tool.displayMessage, "Please approve")
    }

    func testToolInfoIdUniqueness() {
        let tool1 = ToolInfo(id: "codex-123", name: "Codex", icon: "brain", status: .running, lastUpdated: Date())
        let tool2 = ToolInfo(id: "codex-456", name: "Codex", icon: "brain", status: .running, lastUpdated: Date())
        XCTAssertNotEqual(tool1.id, tool2.id)
    }

    func testToolInfoOptionalFields() {
        let tool = ToolInfo(id: "t1", name: "T", icon: "x", status: .idle, lastUpdated: Date())
        XCTAssertNil(tool.workingDirectory)
        XCTAssertNil(tool.terminalApp)
        XCTAssertNil(tool.pid)
    }

    func testToolInfoWithAllFields() {
        let tool = ToolInfo(
            id: "t1",
            name: "Codex",
            icon: "brain",
            status: .running,
            lastUpdated: Date(),
            workingDirectory: "/tmp/project",
            terminalApp: "com.apple.Terminal",
            pid: 12345
        )
        XCTAssertEqual(tool.workingDirectory, "/tmp/project")
        XCTAssertEqual(tool.terminalApp, "com.apple.Terminal")
        XCTAssertEqual(tool.pid, 12345)
    }
}
