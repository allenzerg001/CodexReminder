import Foundation
import Darwin

public enum HookRuntimeState {
    public static let relativeStatePath = ".codexreminder/hook-state.json"

    public static func isEnabled(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        let stateURL = homeDirectory.appendingPathComponent(relativeStatePath)
        guard let data = try? Data(contentsOf: stateURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        guard object["enabled"] as? Bool == true else {
            return false
        }

        if let appPid = object["appPid"] as? Int {
            guard Darwin.kill(pid_t(appPid), 0) == 0 else {
                return false
            }

            if let expectedPath = object["appExecutablePath"] as? String {
                return processCommandPath(pid: appPid) == expectedPath
            }
        }

        return true
    }

    public static func setEnabled(
        _ enabled: Bool,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        appPid: Int32 = Int32(ProcessInfo.processInfo.processIdentifier),
        existingConfigPaths: [String] = []
    ) throws {
        let stateURL = homeDirectory.appendingPathComponent(relativeStatePath)
        try FileManager.default.createDirectory(
            at: stateURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var object: [String: Any] = [
            "enabled": enabled,
            "updatedAt": ISO8601DateFormatter().string(from: Date())
        ]
        if enabled {
            object["appPid"] = Int(appPid)
            object["appExecutablePath"] = Bundle.main.executableURL?.path ?? CommandLine.arguments.first ?? ""
            object["existingConfigPaths"] = existingConfigPaths
        }

        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(to: stateURL, options: .atomic)
    }

    public static func existingConfigPaths(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> Set<String> {
        let stateURL = homeDirectory.appendingPathComponent(relativeStatePath)
        guard let data = try? Data(contentsOf: stateURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let paths = object["existingConfigPaths"] as? [String] else {
            return []
        }

        return Set(paths)
    }

    private static func processCommandPath(pid: Int) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", "\(pid)", "-o", "comm="]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return output.isEmpty ? nil : output
    }
}
