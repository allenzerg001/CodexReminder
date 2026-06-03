import XCTest
@testable import CodexReminderCore

final class ProcessOutputParserTests: XCTestCase {

    // MARK: - parseProcessList

    func testParsesProcessListWithMatches() {
        let output = """
          PID COMM
          123 /usr/local/bin/codex
          456 /usr/bin/vim
          789 /usr/local/bin/codex-agent
        """
        let results = ProcessOutputParser.parseProcessList(output: output, matching: "codex")
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].pid, 123)
        XCTAssertEqual(results[0].command, "/usr/local/bin/codex")
        XCTAssertEqual(results[1].pid, 789)
        XCTAssertEqual(results[1].command, "/usr/local/bin/codex-agent")
    }

    func testParsesProcessListCaseInsensitive() {
        let output = """
          PID COMM
          100 /bin/Claude
          200 /bin/claude-code
        """
        let results = ProcessOutputParser.parseProcessList(output: output, matching: "claude")
        XCTAssertEqual(results.count, 2)
    }

    func testParsesEmptyProcessList() {
        let output = "  PID COMM\n"
        let results = ProcessOutputParser.parseProcessList(output: output, matching: "codex")
        XCTAssertTrue(results.isEmpty)
    }

    func testParsesProcessListNoMatches() {
        let output = """
          PID COMM
          100 /bin/zsh
          200 /usr/bin/vim
        """
        let results = ProcessOutputParser.parseProcessList(output: output, matching: "codex")
        XCTAssertTrue(results.isEmpty)
    }

    func testParsesProcessListWithExtraWhitespace() {
        let output = """
          PID COMM
            42   /usr/local/bin/qoder
        """
        let results = ProcessOutputParser.parseProcessList(output: output, matching: "qoder")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].pid, 42)
    }

    // MARK: - parseLsofCWD

    func testParsesLsofCWD() {
        let output = """
        p12345
        fcwd
        n/Users/dev/project
        """
        let cwd = ProcessOutputParser.parseLsofCWD(output: output)
        XCTAssertEqual(cwd, "/Users/dev/project")
    }

    func testParsesLsofCWDNoMatch() {
        let output = """
        p12345
        fcwd
        tDIR
        """
        let cwd = ProcessOutputParser.parseLsofCWD(output: output)
        XCTAssertNil(cwd)
    }

    func testParsesLsofCWDEmptyOutput() {
        let cwd = ProcessOutputParser.parseLsofCWD(output: "")
        XCTAssertNil(cwd)
    }

    // MARK: - parseLsofFD

    func testParsesLsofFD() {
        let output = """
        p12345
        f0
        n/dev/ttys003
        """
        let fd = ProcessOutputParser.parseLsofFD(output: output)
        XCTAssertEqual(fd, "/dev/ttys003")
    }

    func testParsesLsofFDNoDevPrefix() {
        let output = """
        p12345
        f0
        n/tmp/pipe
        """
        let fd = ProcessOutputParser.parseLsofFD(output: output)
        XCTAssertNil(fd)
    }

    // MARK: - parseProcessState

    func testParsesSleepingForeground() {
        let state = ProcessOutputParser.parseProcessState(output: "S+")
        XCTAssertTrue(state.isSleeping)
        XCTAssertTrue(state.isForeground)
    }

    func testParsesRunningState() {
        let state = ProcessOutputParser.parseProcessState(output: "R+")
        XCTAssertFalse(state.isSleeping)
        XCTAssertTrue(state.isForeground)
    }

    func testParsesBackgroundSleeping() {
        let state = ProcessOutputParser.parseProcessState(output: "S")
        XCTAssertTrue(state.isSleeping)
        XCTAssertFalse(state.isForeground)
    }

    func testParsesStateWithWhitespace() {
        let state = ProcessOutputParser.parseProcessState(output: "  S+  \n")
        XCTAssertTrue(state.isSleeping)
        XCTAssertTrue(state.isForeground)
    }

    // MARK: - isWaitingForInput

    func testIsWaitingForInputTrue() {
        XCTAssertTrue(ProcessOutputParser.isWaitingForInput(stateOutput: "S+"))
    }

    func testIsWaitingForInputFalseWhenRunning() {
        XCTAssertFalse(ProcessOutputParser.isWaitingForInput(stateOutput: "R+"))
    }

    func testIsWaitingForInputFalseWhenBackground() {
        XCTAssertFalse(ProcessOutputParser.isWaitingForInput(stateOutput: "S"))
    }

    // MARK: - parseParentProcess

    func testParsesParentProcess() {
        let result = ProcessOutputParser.parseParentProcess(output: "  1234 Terminal")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.ppid, 1234)
        XCTAssertEqual(result?.command, "Terminal")
    }

    func testParsesParentProcessWithPath() {
        let result = ProcessOutputParser.parseParentProcess(output: "567 /Applications/iTerm.app/Contents/MacOS/iTerm2")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.ppid, 567)
    }

    func testParsesParentProcessInvalidOutput() {
        let result = ProcessOutputParser.parseParentProcess(output: "not a valid output")
        XCTAssertNil(result)
    }

    func testParsesParentProcessEmpty() {
        let result = ProcessOutputParser.parseParentProcess(output: "")
        XCTAssertNil(result)
    }

    // MARK: - isTerminalApp

    func testIsTerminalAppDetectsTerminal() {
        XCTAssertTrue(ProcessOutputParser.isTerminalApp(command: "Terminal"))
        XCTAssertTrue(ProcessOutputParser.isTerminalApp(command: "/Applications/Utilities/Terminal.app"))
    }

    func testIsTerminalAppDetectsITerm() {
        XCTAssertTrue(ProcessOutputParser.isTerminalApp(command: "iTerm2"))
        XCTAssertTrue(ProcessOutputParser.isTerminalApp(command: "/Applications/iTerm.app/Contents/MacOS/iTerm2"))
    }

    func testIsTerminalAppDetectsWarp() {
        XCTAssertTrue(ProcessOutputParser.isTerminalApp(command: "Warp"))
    }

    func testIsTerminalAppDetectsGhostty() {
        XCTAssertTrue(ProcessOutputParser.isTerminalApp(command: "ghostty"))
    }

    func testIsTerminalAppDetectsAlacritty() {
        XCTAssertTrue(ProcessOutputParser.isTerminalApp(command: "alacritty"))
    }

    func testIsTerminalAppDetectsKitty() {
        XCTAssertTrue(ProcessOutputParser.isTerminalApp(command: "kitty"))
    }

    func testIsTerminalAppFalseForNonTerminal() {
        XCTAssertFalse(ProcessOutputParser.isTerminalApp(command: "vim"))
        XCTAssertFalse(ProcessOutputParser.isTerminalApp(command: "node"))
        XCTAssertFalse(ProcessOutputParser.isTerminalApp(command: "codex"))
    }

    // MARK: - extractRecentLines

    func testExtractsRecentLines() {
        let content = (1...30).map { "line \($0)" }.joined(separator: "\n")
        let recent = ProcessOutputParser.extractRecentLines(from: content, count: 5)
        XCTAssertTrue(recent.contains("line 26"))
        XCTAssertTrue(recent.contains("line 30"))
        XCTAssertFalse(recent.contains("line 25"))
    }

    func testExtractsAllLinesWhenFewerThanCount() {
        let content = "line 1\nline 2\nline 3"
        let recent = ProcessOutputParser.extractRecentLines(from: content, count: 20)
        XCTAssertEqual(recent, content)
    }

    func testExtractsRecentLinesEmpty() {
        let recent = ProcessOutputParser.extractRecentLines(from: "", count: 5)
        XCTAssertEqual(recent, "")
    }

    // MARK: - shortenPath

    func testShortenPathWithHome() {
        let shortened = ProcessOutputParser.shortenPath(
            "/Users/dev/projects/myapp",
            homeDir: "/Users/dev"
        )
        XCTAssertEqual(shortened, "~/projects/myapp")
    }

    func testShortenPathWithoutHome() {
        let shortened = ProcessOutputParser.shortenPath(
            "/opt/data/project",
            homeDir: "/Users/dev"
        )
        XCTAssertEqual(shortened, "/opt/data/project")
    }

    func testShortenPathExactHome() {
        let shortened = ProcessOutputParser.shortenPath(
            "/Users/dev",
            homeDir: "/Users/dev"
        )
        XCTAssertEqual(shortened, "~")
    }
}
