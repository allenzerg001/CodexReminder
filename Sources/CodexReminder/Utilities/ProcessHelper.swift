import Foundation

struct ProcessInfo {
    let pid: Int32
    let name: String
    let cwd: String?
    let command: String
}

enum ProcessHelper {

    private static func run(_ executable: String, arguments: [String], timeout: TimeInterval = 3.0) -> String? {
        let outPipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = outPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        // Read output on a separate thread to avoid deadlock
        var outputData = Data()
        let readQueue = DispatchQueue(label: "com.codexreminder.read")
        let sem = DispatchSemaphore(value: 0)
        readQueue.async {
            outputData = outPipe.fileHandleForReading.readDataToEndOfFile()
            sem.signal()
        }

        let result = sem.wait(timeout: .now() + timeout)
        if result == .timedOut {
            process.terminate()
            return nil
        }

        process.waitUntilExit()
        return String(data: outputData, encoding: .utf8)
    }

    static func findProcesses(matching name: String) -> [ProcessInfo] {
        guard let output = run("/bin/ps", arguments: ["-eo", "pid,args"]) else {
            return []
        }

        var results: [ProcessInfo] = []
        let lines = output.components(separatedBy: "\n")
        let selfPid = Foundation.ProcessInfo.processInfo.processIdentifier

        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.split(separator: " ", maxSplits: 1)
            guard parts.count == 2,
                  let pid = Int32(parts[0]) else { continue }
            guard pid != selfPid else { continue }

            let comm = String(parts[1])
            guard !comm.contains("CodexReminder") else { continue }
            if comm.lowercased().contains(name.lowercased()) {
                results.append(ProcessInfo(
                    pid: pid,
                    name: comm,
                    cwd: nil,
                    command: comm
                ))
            }
        }
        return results
    }

    static func getTerminalFD(pid: Int32) -> String? {
        guard let output = run("/usr/sbin/lsof", arguments: ["-a", "-p", "\(pid)", "-d", "0", "-Fn"], timeout: 1.0) else {
            return nil
        }
        for line in output.components(separatedBy: "\n") {
            if line.hasPrefix("n/dev/") {
                return String(line.dropFirst())
            }
        }
        return nil
    }

    static func readRecentOutput(fd: String, pid: Int32) -> String? {
        let logPath = "/tmp/codexreminder_\(pid).log"
        if FileManager.default.fileExists(atPath: logPath) {
            guard let data = FileManager.default.contents(atPath: logPath),
                  let content = String(data: data, encoding: .utf8) else { return nil }
            return content.components(separatedBy: "\n").suffix(20).joined(separator: "\n")
        }
        return nil
    }

    static func isProcessWaitingForInput(pid: Int32) -> Bool {
        guard let output = run("/bin/ps", arguments: ["-p", "\(pid)", "-o", "state="], timeout: 1.0) else {
            return false
        }
        let state = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return state.contains("S") && state.contains("+")
    }
}
