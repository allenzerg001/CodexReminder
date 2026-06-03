import XCTest
@testable import CodexReminderCore

final class StateEngineTests: XCTestCase {

    // MARK: - computeSnapshot

    func testSnapshotWithNoTools() {
        let snapshot = StateEngine.computeSnapshot(previousTools: [], detectedTools: [])
        XCTAssertTrue(snapshot.tools.isEmpty)
        XCTAssertFalse(snapshot.isAnimating)
        XCTAssertTrue(snapshot.newlyWaitingIds.isEmpty)
    }

    func testSnapshotDetectsNewlyWaiting() {
        let previous: [ToolInfo] = []
        let detected = [
            makeToolInfo(id: "codex-1", status: .waitingForAuth(message: "Approval needed"))
        ]

        let snapshot = StateEngine.computeSnapshot(previousTools: previous, detectedTools: detected)
        XCTAssertTrue(snapshot.isAnimating)
        XCTAssertEqual(snapshot.newlyWaitingIds, ["codex-1"])
    }

    func testSnapshotDoesNotReNotifyExistingWaiting() {
        let previous = [
            makeToolInfo(id: "codex-1", status: .waitingForAuth(message: "Approval needed"))
        ]
        let detected = [
            makeToolInfo(id: "codex-1", status: .waitingForAuth(message: "Approval needed"))
        ]

        let snapshot = StateEngine.computeSnapshot(previousTools: previous, detectedTools: detected)
        XCTAssertTrue(snapshot.isAnimating)
        XCTAssertTrue(snapshot.newlyWaitingIds.isEmpty)
    }

    func testSnapshotDetectsMultipleNewlyWaiting() {
        let previous = [
            makeToolInfo(id: "codex-1", status: .running)
        ]
        let detected = [
            makeToolInfo(id: "codex-1", status: .waitingForInput(message: "Input needed")),
            makeToolInfo(id: "claude-2", status: .waitingForAuth(message: "Permission")),
            makeToolInfo(id: "qoder-3", status: .running)
        ]

        let snapshot = StateEngine.computeSnapshot(previousTools: previous, detectedTools: detected)
        XCTAssertTrue(snapshot.isAnimating)
        XCTAssertEqual(snapshot.newlyWaitingIds, ["codex-1", "claude-2"])
    }

    func testSnapshotStopsAnimatingWhenResolved() {
        let previous = [
            makeToolInfo(id: "codex-1", status: .waitingForAuth(message: "Approval"))
        ]
        let detected = [
            makeToolInfo(id: "codex-1", status: .running)
        ]

        let snapshot = StateEngine.computeSnapshot(previousTools: previous, detectedTools: detected)
        XCTAssertFalse(snapshot.isAnimating)
        XCTAssertTrue(snapshot.newlyWaitingIds.isEmpty)
    }

    func testSnapshotToolDisappears() {
        let previous = [
            makeToolInfo(id: "codex-1", status: .waitingForAuth(message: "Approval"))
        ]
        let detected: [ToolInfo] = []

        let snapshot = StateEngine.computeSnapshot(previousTools: previous, detectedTools: detected)
        XCTAssertFalse(snapshot.isAnimating)
        XCTAssertTrue(snapshot.tools.isEmpty)
    }

    // MARK: - toolsNeedingAttention

    func testToolsNeedingAttention() {
        let tools = [
            makeToolInfo(id: "1", status: .waitingForAuth(message: "Auth")),
            makeToolInfo(id: "2", status: .running),
            makeToolInfo(id: "3", status: .waitingForInput(message: "Input")),
            makeToolInfo(id: "4", status: .idle)
        ]
        let waiting = StateEngine.toolsNeedingAttention(tools)
        XCTAssertEqual(waiting.count, 2)
        XCTAssertEqual(Set(waiting.map(\.id)), ["1", "3"])
    }

    func testToolsNeedingAttentionEmpty() {
        let tools = [
            makeToolInfo(id: "1", status: .running),
            makeToolInfo(id: "2", status: .idle)
        ]
        let waiting = StateEngine.toolsNeedingAttention(tools)
        XCTAssertTrue(waiting.isEmpty)
    }

    // MARK: - runningTools

    func testRunningTools() {
        let tools = [
            makeToolInfo(id: "1", status: .waitingForAuth(message: "Auth")),
            makeToolInfo(id: "2", status: .running),
            makeToolInfo(id: "3", status: .idle)
        ]
        let running = StateEngine.runningTools(tools)
        XCTAssertEqual(running.count, 1)
        XCTAssertEqual(running[0].id, "2")
    }

    // MARK: - Helpers

    private func makeToolInfo(id: String, status: ToolStatus) -> ToolInfo {
        ToolInfo(
            id: id,
            name: "Test",
            icon: "brain",
            status: status,
            lastUpdated: Date(),
            workingDirectory: nil,
            terminalApp: nil,
            pid: nil
        )
    }
}
