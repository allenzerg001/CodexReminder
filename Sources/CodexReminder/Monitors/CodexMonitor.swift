import Foundation
import CodexReminderCore

struct CodexMonitor: ToolMonitor {
    let toolName = "Codex"

    private let skipPatterns = ["app-server", "extension-host", "CodexBar"]

    func detectInstances() -> [ToolInfo] {
        let processes = ProcessHelper.findProcesses(matching: "codex")
        var results: [ToolInfo] = []

        for proc in processes {
            if skipPatterns.contains(where: { proc.command.contains($0) }) {
                continue
            }

            let status = checkStatus(pid: proc.pid)
            if status != .idle {
                results.append(ToolInfo(
                    id: "codex-\(proc.pid)",
                    name: "Codex",
                    icon: "brain.head.profile",
                    status: status,
                    lastUpdated: Date(),
                    workingDirectory: proc.cwd,
                    terminalApp: nil,
                    pid: proc.pid
                ))
            }
        }
        return results
    }

    private func checkStatus(pid: Int32) -> ToolStatus {
        guard ProcessHelper.isProcessWaitingForInput(pid: pid) else {
            return .idle
        }

        guard let fd = ProcessHelper.getTerminalFD(pid: pid) else {
            return .waitingForInput(message: "Waiting for input")
        }

        let lastOutput = ProcessHelper.readRecentOutput(fd: fd, pid: pid)
        return OutputAnalyzer.determineStatus(
            output: lastOutput,
            isProcessSleeping: true,
            authKeywords: OutputAnalyzer.codexAuthKeywords
        )
    }
}
