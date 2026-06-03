import AppKit
import UserNotifications
import CodexReminderCore

@main
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, NSTouchBarProvider {
    private static var retainedDelegate: AppDelegate?

    private var touchBarController: TouchBarController?
    private var statusBarController: StatusBarController?
    private var hookInstallationManager: HookInstallationManager?

    static func main() {
        fileLog("CodexReminder main entered")
        let app = NSApplication.shared
        let delegate = AppDelegate()
        retainedDelegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        app.run()
    }

    @MainActor
    var touchBar: NSTouchBar? {
        touchBarController?.touchBar
    }

    @MainActor
    private func attachTouchBar(appState: AppState) {
        if touchBarController == nil {
            touchBarController = TouchBarController(appState: appState)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        fileLog("CodexReminder application launched")
        let appState = AppState.shared
        setApplicationIcon()

        Task { @MainActor in
            statusBarController = StatusBarController(appState: appState)
            attachTouchBar(appState: appState)
        }

        installHooks()

        guard appState.showNotifications else {
            fileLog("Skipped notification permission request")
            return
        }

        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                NSLog("[CodexReminder] Notification permission granted")
            } else {
                NSLog("[CodexReminder] Notification permission denied: \(error?.localizedDescription ?? "unknown")")
            }
        }
    }

    private func setApplicationIcon() {
        guard let image = Self.applicationIconImage() else {
            fileLog("Failed to load CodexReminder application icon resource")
            return
        }

        NSApplication.shared.applicationIconImage = image
    }

    private static func applicationIconImage() -> NSImage? {
        AppIconResource.image()
    }

    func applicationWillTerminate(_ notification: Notification) {
        uninstallHooks()
    }

    private func installHooks() {
        guard !Self.shouldSkipHookInstallation else {
            fileLog("Skipped CodexReminder hook installation")
            return
        }

        let manager = HookInstallationManager(hookExecutablePath: Self.hookExecutablePath())
        do {
            try manager.install()
            hookInstallationManager = manager
            fileLog("Installed CodexReminder hooks")
        } catch {
            fileLog("Failed to install CodexReminder hooks: \(error.localizedDescription)")
        }
    }

    private func uninstallHooks() {
        guard !Self.shouldSkipHookInstallation else {
            fileLog("Skipped CodexReminder hook uninstall")
            return
        }

        let manager = hookInstallationManager ?? HookInstallationManager(hookExecutablePath: Self.hookExecutablePath())
        do {
            try manager.uninstall()
            fileLog("Uninstalled CodexReminder hooks")
        } catch {
            fileLog("Failed to uninstall CodexReminder hooks: \(error.localizedDescription)")
        }
    }

    private static func hookExecutablePath() -> String {
        let bundledURL = Bundle.main.executableURL?
            .deletingLastPathComponent()
            .appendingPathComponent("CodexReminderHook")

        if let bundledURL, FileManager.default.isExecutableFile(atPath: bundledURL.path) {
            return bundledURL.path
        }

        return "CodexReminderHook"
    }

    private static var shouldSkipHookInstallation: Bool {
        let value = Foundation.ProcessInfo.processInfo.environment["CODEX_REMINDER_SKIP_HOOK_INSTALL"] ?? ""
        return ["1", "true", "yes"].contains(value.lowercased())
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
