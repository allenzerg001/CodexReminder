import SwiftUI
import Combine
import UserNotifications
import CodexReminderCore

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var tools: [ToolInfo] = []
    @Published var isAnimating: Bool = false
    @Published var showNotifications: Bool = true

    private var monitors: [ToolMonitor] = []
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    private var isTouchBarPreviewMode: Bool = false

    init() {
        if configureTouchBarPreviewIfNeeded() {
            return
        }

        setupMonitors()
        startPolling()
    }

    private func configureTouchBarPreviewIfNeeded() -> Bool {
        guard let previewValue = Self.touchBarPreviewValue(),
              !previewValue.trimmingCharacters(in: Foundation.CharacterSet.whitespacesAndNewlines).isEmpty else {
            return false
        }

        showNotifications = false
        isTouchBarPreviewMode = true
        tools = Self.previewTools(for: previewValue)
        isAnimating = tools.contains { $0.status.isWaiting }
        fileLog("App started in Touch Bar preview mode: \(previewValue)")
        return true
    }

    private static func touchBarPreviewValue() -> String? {
        let environment = Foundation.ProcessInfo.processInfo.environment
        if let value = environment["CODEX_REMINDER_TOUCHBAR_PREVIEW"] {
            return value
        }

        let arguments = CommandLine.arguments
        for index in arguments.indices {
            let argument = arguments[index]
            if argument == "--touchbar-preview", index + 1 < arguments.count {
                return arguments[index + 1]
            }
            if argument.hasPrefix("--touchbar-preview=") {
                return String(argument.dropFirst("--touchbar-preview=".count))
            }
        }

        return nil
    }

    private func setupMonitors() {
        monitors = [
            FileBasedMonitor()
        ]
        fileLog("App started, hook monitor initialized")
    }

    private func startPolling() {
        let monitors = self.monitors
        let queue = DispatchQueue(label: "com.codexreminder.poll", qos: .utility)
        queue.async { [weak self] in
            while true {
                var newTools: [ToolInfo] = []
                for monitor in monitors {
                    newTools.append(contentsOf: monitor.detectInstances())
                }
                DispatchQueue.main.async { [weak self] in
                    self?.updateState(with: newTools)
                }
                Thread.sleep(forTimeInterval: 3.0)
            }
        }
    }

    private func updateState(with newTools: [ToolInfo]) {
        let previousWaitingIds = Set(tools.filter { $0.status.isWaiting }.map { $0.id })
        let snapshot = StateEngine.computeSnapshot(previousTools: tools, detectedTools: newTools)
        tools = snapshot.tools
        isAnimating = snapshot.isAnimating
        let currentWaitingIds = Set(snapshot.tools.filter { $0.status.isWaiting }.map { $0.id })
        clearNotifications(for: previousWaitingIds.subtracting(currentWaitingIds))

        if showNotifications {
            for toolId in snapshot.newlyWaitingIds {
                if let tool = newTools.first(where: { $0.id == toolId }) {
                    fileLog("ALERT: \(tool.name) - \(tool.displayMessage)")
                    sendNotification(for: tool)
                }
            }
        }
    }

    private func sendNotification(for tool: ToolInfo) {
        fileLog("Sending notification for: \(tool.name)")
        let content = UNMutableNotificationContent()
        content.title = "\(tool.name) needs attention"
        content.body = tool.displayMessage
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: tool.id,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func clearNotifications(for toolIds: Set<String>) {
        guard showNotifications, !toolIds.isEmpty else {
            return
        }

        let ids = Array(toolIds)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
    }

    func activateTool(_ tool: ToolInfo) {
        if let pid = tool.pid {
            activateTerminalWithPid(pid)
        } else if let app = tool.terminalApp {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app) {
                NSWorkspace.shared.openApplication(at: url, configuration: .init())
            }
        }
    }

    func choose(_ choice: ToolChoice, for tool: ToolInfo) {
        if !isTouchBarPreviewMode {
            HookResponseWriter.write(choice: choice, for: tool)
        }
        tools.removeAll { $0.id == tool.id }
        isAnimating = tools.contains { $0.status.isWaiting }
    }

    private func activateTerminalWithPid(_ pid: Int32) {
        let apps = NSWorkspace.shared.runningApplications
        if let app = apps.first(where: { $0.processIdentifier == pid }) {
            app.activate()
        } else {
            for app in apps where app.bundleIdentifier == "com.apple.Terminal"
                || app.bundleIdentifier == "com.googlecode.iterm2"
                || app.bundleIdentifier == "dev.warp.Warp-Stable"
                || app.bundleIdentifier == "com.mitchellh.ghostty" {
                app.activate()
                break
            }
        }
    }

    private static func previewTools(for value: String) -> [ToolInfo] {
        let normalized = value.lowercased()
        let allTools = [
            previewTool(
                id: "preview-codex",
                name: "Codex",
                icon: "brain.head.profile",
                message: "Allow shell command?",
                log: "Shell: touch /tmp/codexreminder_touchbar_preview"
            ),
            previewTool(
                id: "preview-claude",
                name: "Claude Code",
                icon: "sparkle",
                message: "Permission needed",
                log: "Bash: npm test -- --watch=false"
            ),
            previewTool(
                id: "preview-qoder",
                name: "Qoder CLI",
                icon: "hammer",
                message: "Approve workspace edit?",
                log: "Edit: Sources/CodexReminder/TouchBar/TouchBarController.swift"
            )
        ]

        if normalized == "all" {
            return allTools
        }

        return allTools.filter { $0.name.lowercased().contains(normalized) }
    }

    private static func previewTool(
        id: String,
        name: String,
        icon: String,
        message: String,
        log: String
    ) -> ToolInfo {
        ToolInfo(
            id: id,
            name: name,
            icon: icon,
            status: .waitingForAuth(message: message),
            lastUpdated: Date(),
            workingDirectory: FileManager.default.currentDirectoryPath,
            log: log,
            choices: [
                ToolChoice(id: "allow", title: "Allow", value: "allow"),
                ToolChoice(id: "deny", title: "Deny", value: "deny")
            ]
        )
    }
}
