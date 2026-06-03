import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let appState: AppState
    private var cancellable: AnyCancellable?
    private var isPulseOn = false
    private var timer: Timer?

    init(appState: AppState) {
        self.appState = appState
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        configurePopover()
        configureButton()
        updateIcon()

        cancellable = appState.$tools.sink { [weak self] _ in
            self?.updateIcon()
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else {
                    return
                }
                self.isPulseOn.toggle()
                self.updateIcon()
            }
        }
    }

    deinit {
        timer?.invalidate()
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView().environmentObject(appState)
        )
    }

    private func configureButton() {
        guard let button = statusItem.button else {
            return
        }

        statusItem.length = NSStatusItem.squareLength
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.alternateTitle = ""
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.setContentHuggingPriority(.required, for: .horizontal)
    }

    private func updateIcon() {
        guard let button = statusItem.button else {
            return
        }

        statusItem.length = NSStatusItem.squareLength
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.alternateTitle = ""
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.image = MenuBarIconRenderer.render(waitingCount: waitingCount, isPulseOn: isPulseOn)
        button.image?.isTemplate = false
        button.toolTip = waitingCount > 0 ? "\(waitingCount) AI requests need attention" : "AI Coding Monitor"
    }

    private var waitingCount: Int {
        appState.tools.filter { $0.status.isWaiting }.count
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }

        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }
}
