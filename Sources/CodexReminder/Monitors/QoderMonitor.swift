import Foundation
import CodexReminderCore

struct QoderMonitor: ToolMonitor {
    let toolName = "Qoder"

    func detectInstances() -> [ToolInfo] {
        let processes = ProcessHelper.findProcesses(matching: "qoder")
        var results: [ToolInfo] = []

        for proc in processes {
            if proc.command.contains("--dangerously-skip-permissions") {
                continue
            }

            let status = checkStatus(pid: proc.pid)
            if status != .idle {
                results.append(ToolInfo(
                    id: "qoder-\(proc.pid)",
                    name: "Qoder",
                    icon: "hammer",
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
            return .idle
        }

        guard let lastOutput = ProcessHelper.readRecentOutput(fd: fd, pid: pid) else {
            return .idle
        }

        return OutputAnalyzer.determineStatus(
            output: lastOutput,
            isProcessSleeping: true,
            authKeywords: OutputAnalyzer.qoderAuthKeywords
        )
    }
}
