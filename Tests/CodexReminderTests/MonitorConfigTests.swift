import XCTest
@testable import CodexReminderCore

final class MonitorConfigTests: XCTestCase {

    func testCodexConfigValues() {
        let config = MonitorConfig.codex
        XCTAssertEqual(config.toolName, "Codex")
        XCTAssertEqual(config.processNamePattern, "codex")
        XCTAssertEqual(config.iconName, "brain.head.profile")
        XCTAssertFalse(config.authKeywords.isEmpty)
    }

    func testClaudeCodeConfigValues() {
        let config = MonitorConfig.claudeCode
        XCTAssertEqual(config.toolName, "Claude Code")
        XCTAssertEqual(config.processNamePattern, "claude")
        XCTAssertEqual(config.iconName, "sparkle")
        XCTAssertFalse(config.authKeywords.isEmpty)
    }

    func testQoderConfigValues() {
        let config = MonitorConfig.qoder
        XCTAssertEqual(config.toolName, "Qoder")
        XCTAssertEqual(config.processNamePattern, "qoder")
        XCTAssertEqual(config.iconName, "hammer")
        XCTAssertFalse(config.authKeywords.isEmpty)
    }

    func testAllDefaultsContainsThreeConfigs() {
        XCTAssertEqual(MonitorConfig.allDefaults.count, 3)
    }

    func testConfigEquality() {
        XCTAssertEqual(MonitorConfig.codex, MonitorConfig.codex)
        XCTAssertNotEqual(MonitorConfig.codex, MonitorConfig.qoder)
    }

    func testCodexKeywordsContainExpectedPatterns() {
        let keywords = MonitorConfig.codex.authKeywords
        XCTAssertTrue(keywords.contains("(y/n)"))
        XCTAssertTrue(keywords.contains("approve"))
    }

    func testClaudeKeywordsContainDenyPattern() {
        let keywords = MonitorConfig.claudeCode.authKeywords
        XCTAssertTrue(keywords.contains("Deny"))
    }
}
