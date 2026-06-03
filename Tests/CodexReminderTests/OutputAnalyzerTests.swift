import XCTest
@testable import CodexReminderCore

final class OutputAnalyzerTests: XCTestCase {

    // MARK: - Codex Auth Detection

    func testDetectsCodexApprovalPrompt() {
        let output = "Some output\nDo you want to proceed?\n> "
        let result = OutputAnalyzer.analyze(output: output, keywords: OutputAnalyzer.codexAuthKeywords)
        XCTAssertTrue(result.hasAuthKeywords)
        XCTAssertTrue(result.matchedKeywords.contains("Do you want to proceed?"))
    }

    func testDetectsYesNoPrompt() {
        let output = "Apply changes? (y/n)"
        let result = OutputAnalyzer.analyze(output: output, keywords: OutputAnalyzer.codexAuthKeywords)
        XCTAssertTrue(result.hasAuthKeywords)
        XCTAssertTrue(result.matchedKeywords.contains("(y/n)"))
    }

    func testDetectsApproveKeyword() {
        let output = "Please approve the following changes:"
        let result = OutputAnalyzer.analyze(output: output, keywords: OutputAnalyzer.codexAuthKeywords)
        XCTAssertTrue(result.hasAuthKeywords)
        XCTAssertTrue(result.matchedKeywords.contains("approve"))
    }

    func testDetectsAllowKeyword() {
        let output = "Allow this tool to write files?"
        let result = OutputAnalyzer.analyze(output: output, keywords: OutputAnalyzer.codexAuthKeywords)
        XCTAssertTrue(result.hasAuthKeywords)
        XCTAssertTrue(result.matchedKeywords.contains("Allow"))
    }

    func testNoMatchOnNormalOutput() {
        let output = "Generating code...\nDone! File saved."
        let result = OutputAnalyzer.analyze(output: output, keywords: OutputAnalyzer.codexAuthKeywords)
        XCTAssertFalse(result.hasAuthKeywords)
        XCTAssertTrue(result.matchedKeywords.isEmpty)
    }

    func testDetectsQuestionMark() {
        let output = "What file should I modify?"
        let result = OutputAnalyzer.analyze(output: output, keywords: OutputAnalyzer.codexAuthKeywords)
        XCTAssertTrue(result.hasQuestionMark)
    }

    func testNoQuestionMarkInNormalOutput() {
        let output = "Processing file main.swift"
        let result = OutputAnalyzer.analyze(output: output, keywords: OutputAnalyzer.codexAuthKeywords)
        XCTAssertFalse(result.hasQuestionMark)
    }

    // MARK: - Claude Code Auth Detection

    func testDetectsClaudePermissionPrompt() {
        let output = "Claude wants to edit main.swift\n[Allow] [Deny]"
        let result = OutputAnalyzer.analyze(output: output, keywords: OutputAnalyzer.claudeAuthKeywords)
        XCTAssertTrue(result.hasAuthKeywords)
        XCTAssertTrue(result.matchedKeywords.contains("Allow"))
        XCTAssertTrue(result.matchedKeywords.contains("Deny"))
    }

    func testDetectsClaudeDoYouWant() {
        let output = "Do you want to run this command?"
        let result = OutputAnalyzer.analyze(output: output, keywords: OutputAnalyzer.claudeAuthKeywords)
        XCTAssertTrue(result.hasAuthKeywords)
        XCTAssertTrue(result.matchedKeywords.contains("Do you want to"))
    }

    func testDetectsClaudePermissionKeyword() {
        let output = "Requesting permission to access files"
        let result = OutputAnalyzer.analyze(output: output, keywords: OutputAnalyzer.claudeAuthKeywords)
        XCTAssertTrue(result.hasAuthKeywords)
        XCTAssertTrue(result.matchedKeywords.contains("permission"))
    }

    // MARK: - Qoder Auth Detection

    func testDetectsQoderApproval() {
        let output = "Tool call requires approval:\nbash: rm -rf /tmp/test"
        let result = OutputAnalyzer.analyze(output: output, keywords: OutputAnalyzer.qoderAuthKeywords)
        XCTAssertTrue(result.hasAuthKeywords)
    }

    func testDetectsQoderPermission() {
        let output = "This action requires permission"
        let result = OutputAnalyzer.analyze(output: output, keywords: OutputAnalyzer.qoderAuthKeywords)
        XCTAssertTrue(result.hasAuthKeywords)
    }

    // MARK: - Multiple Keywords

    func testMultipleKeywordsMatched() {
        let output = "Do you want to proceed? Allow changes? (y/n)"
        let result = OutputAnalyzer.analyze(output: output, keywords: OutputAnalyzer.codexAuthKeywords)
        XCTAssertEqual(result.matchedKeywords.count, 3)
    }

    // MARK: - determineStatus

    func testStatusWaitingForAuthWhenKeywordsMatch() {
        let output = "Do you want to proceed?"
        let status = OutputAnalyzer.determineStatus(
            output: output,
            isProcessSleeping: true,
            authKeywords: OutputAnalyzer.codexAuthKeywords
        )
        XCTAssertEqual(status, .waitingForAuth(message: "Waiting for approval"))
    }

    func testStatusWaitingForInputWhenQuestionAndSleeping() {
        let output = "Which file should I edit?"
        let status = OutputAnalyzer.determineStatus(
            output: output,
            isProcessSleeping: true,
            authKeywords: OutputAnalyzer.codexAuthKeywords
        )
        XCTAssertEqual(status, .waitingForInput(message: "Waiting for user input"))
    }

    func testStatusRunningWhenQuestionButNotSleeping() {
        let output = "Which file should I edit?"
        let status = OutputAnalyzer.determineStatus(
            output: output,
            isProcessSleeping: false,
            authKeywords: OutputAnalyzer.codexAuthKeywords
        )
        XCTAssertEqual(status, .running)
    }

    func testStatusWaitingForInputWhenNoOutputButSleeping() {
        let status = OutputAnalyzer.determineStatus(
            output: nil,
            isProcessSleeping: true,
            authKeywords: OutputAnalyzer.codexAuthKeywords
        )
        XCTAssertEqual(status, .waitingForInput(message: "Waiting for input"))
    }

    func testStatusRunningWhenNoOutputNotSleeping() {
        let status = OutputAnalyzer.determineStatus(
            output: nil,
            isProcessSleeping: false,
            authKeywords: OutputAnalyzer.codexAuthKeywords
        )
        XCTAssertEqual(status, .running)
    }

    func testAuthKeywordsTakePriorityOverQuestion() {
        let output = "Allow this operation? (y/n)"
        let status = OutputAnalyzer.determineStatus(
            output: output,
            isProcessSleeping: true,
            authKeywords: OutputAnalyzer.codexAuthKeywords
        )
        XCTAssertEqual(status, .waitingForAuth(message: "Waiting for approval"))
    }
}
