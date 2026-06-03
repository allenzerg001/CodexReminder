import XCTest
@testable import CodexReminderCore

final class ToolStatusTests: XCTestCase {

    func testIdleIsNotWaiting() {
        XCTAssertFalse(ToolStatus.idle.isWaiting)
    }

    func testRunningIsNotWaiting() {
        XCTAssertFalse(ToolStatus.running.isWaiting)
    }

    func testWaitingForInputIsWaiting() {
        XCTAssertTrue(ToolStatus.waitingForInput(message: "test").isWaiting)
    }

    func testWaitingForAuthIsWaiting() {
        XCTAssertTrue(ToolStatus.waitingForAuth(message: "test").isWaiting)
    }

    func testDisplayMessages() {
        XCTAssertEqual(ToolStatus.idle.displayMessage, "Idle")
        XCTAssertEqual(ToolStatus.running.displayMessage, "Running...")
        XCTAssertEqual(ToolStatus.waitingForInput(message: "Need input").displayMessage, "Need input")
        XCTAssertEqual(ToolStatus.waitingForAuth(message: "Need auth").displayMessage, "Need auth")
    }

    func testEquality() {
        XCTAssertEqual(ToolStatus.idle, ToolStatus.idle)
        XCTAssertEqual(ToolStatus.running, ToolStatus.running)
        XCTAssertEqual(ToolStatus.waitingForInput(message: "a"), ToolStatus.waitingForInput(message: "a"))
        XCTAssertNotEqual(ToolStatus.waitingForInput(message: "a"), ToolStatus.waitingForInput(message: "b"))
        XCTAssertNotEqual(ToolStatus.waitingForInput(message: "x"), ToolStatus.waitingForAuth(message: "x"))
    }
}
