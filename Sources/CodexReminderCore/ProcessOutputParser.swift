import Foundation

public enum ProcessOutputParser {

    public static func parseProcessList(output: String, matching name: String) -> [(pid: Int32, command: String)] {
        var results: [(pid: Int32, command: String)] = []
        let lines = output.components(separatedBy: "\n")

        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.split(separator: " ", maxSplits: 1)
            guard parts.count == 2,
                  let pid = Int32(parts[0]) else { continue }

            let comm = String(parts[1])
            if comm.lowercased().contains(name.lowercased()) {
                results.append((pid: pid, command: comm))
            }
        }
        return results
    }

    public static func parseLsofCWD(output: String) -> String? {
        for line in output.components(separatedBy: "\n") {
            if line.hasPrefix("n/") {
                return String(line.dropFirst())
            }
        }
        return nil
    }

    public static func parseLsofFD(output: String) -> String? {
        for line in output.components(separatedBy: "\n") {
            if line.hasPrefix("n/dev/") {
                return String(line.dropFirst())
            }
        }
        return nil
    }

    public static func parseProcessState(output: String) -> (isSleeping: Bool, isForeground: Bool) {
        let state = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return (isSleeping: state.contains("S"), isForeground: state.contains("+"))
    }

    public static func isWaitingForInput(stateOutput: String) -> Bool {
        let parsed = parseProcessState(output: stateOutput)
        return parsed.isSleeping && parsed.isForeground
    }

    public static func parseParentProcess(output: String) -> (ppid: Int32, command: String)? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ", maxSplits: 1)
        guard parts.count == 2, let ppid = Int32(parts[0]) else { return nil }
        return (ppid: ppid, command: String(parts[1]))
    }

    public static let terminalAppNames = ["terminal", "iterm", "warp", "ghostty", "alacritty", "kitty"]

    public static func isTerminalApp(command: String) -> Bool {
        let lower = command.lowercased()
        return terminalAppNames.contains { lower.contains($0) }
    }

    public static func extractRecentLines(from content: String, count: Int = 20) -> String {
        let lines = content.components(separatedBy: "\n")
        return lines.suffix(count).joined(separator: "\n")
    }

    public static func shortenPath(_ path: String, homeDir: String) -> String {
        if path.hasPrefix(homeDir) {
            return "~" + path.dropFirst(homeDir.count)
        }
        return path
    }
}
