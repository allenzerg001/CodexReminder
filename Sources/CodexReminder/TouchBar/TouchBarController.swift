import AppKit
import Combine
import CodexReminderCore

private final class TouchBarHostWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class TouchBarHostView: NSView {
    override var acceptsFirstResponder: Bool { true }
}

private struct TouchBarPresentationKey: Equatable {
    let toolID: String
    let message: String
    let log: String
    let choices: [ToolChoice]
    let requestPath: String?
    let responsePath: String?

    init(tool: ToolInfo) {
        toolID = tool.id
        message = tool.displayMessage
        log = tool.displayLog
        choices = tool.choices
        requestPath = tool.requestPath
        responsePath = tool.responsePath
    }
}

@MainActor
final class TouchBarController: NSObject, NSTouchBarDelegate {
    private enum Item {
        static let prefix = "com.codexreminder.touchbar"

        static func summary(for tool: ToolInfo) -> NSTouchBarItem.Identifier {
            NSTouchBarItem.Identifier("\(prefix).summary.\(safeId(tool.id))")
        }

        static func log(for tool: ToolInfo) -> NSTouchBarItem.Identifier {
            NSTouchBarItem.Identifier("\(prefix).log.\(safeId(tool.id))")
        }

        static func choices(for tool: ToolInfo) -> NSTouchBarItem.Identifier {
            NSTouchBarItem.Identifier("\(prefix).choices.\(safeId(tool.id))")
        }

        static func activate(for tool: ToolInfo) -> NSTouchBarItem.Identifier {
            NSTouchBarItem.Identifier("\(prefix).activate.\(safeId(tool.id))")
        }

        static func isSummary(_ identifier: NSTouchBarItem.Identifier) -> Bool {
            identifier.rawValue.hasPrefix("\(prefix).summary.")
        }

        static func isLog(_ identifier: NSTouchBarItem.Identifier) -> Bool {
            identifier.rawValue.hasPrefix("\(prefix).log.")
        }

        static func isChoices(_ identifier: NSTouchBarItem.Identifier) -> Bool {
            identifier.rawValue.hasPrefix("\(prefix).choices.")
        }

        static func isActivate(_ identifier: NSTouchBarItem.Identifier) -> Bool {
            identifier.rawValue.hasPrefix("\(prefix).activate.")
        }

        static func choice(for tool: ToolInfo, choice: ToolChoice) -> NSTouchBarItem.Identifier {
            NSTouchBarItem.Identifier("\(prefix).choice.\(safeId(tool.id)).\(safeId(choice.id))")
        }

        private static func safeId(_ value: String) -> String {
            value.map { $0.isLetter || $0.isNumber ? $0 : "-" }.reduce("") { $0 + String($1) }
        }
    }

    private let appState: AppState
    private var cancellable: AnyCancellable?
    let touchBar = NSTouchBar()
    private var choiceItems: [NSTouchBarItem.Identifier: (ToolInfo, ToolChoice)] = [:]
    private var hostWindow: NSWindow?
    private var hostView: NSView?
    private var lastPresentationLogToolID: String?
    private var presentationKey: TouchBarPresentationKey?

    init(appState: AppState) {
        self.appState = appState
        super.init()
        configureTouchBar()

        cancellable = appState.$tools.sink { [weak self] _ in
            Task { @MainActor in
                self?.refreshTouchBar()
            }
        }
    }

    private func configureTouchBar() {
        touchBar.delegate = self
        touchBar.customizationIdentifier = NSTouchBar.CustomizationIdentifier("com.codexreminder.touchbar")
        touchBar.defaultItemIdentifiers = []
        NSApplication.shared.touchBar = touchBar
    }

    private func refreshTouchBar() {
        let waitingTool = currentTool
        choiceItems.removeAll()

        if waitingTool == nil {
            guard presentationKey != nil || !touchBar.defaultItemIdentifiers.isEmpty else {
                return
            }
            touchBar.defaultItemIdentifiers = []
            touchBar.principalItemIdentifier = nil
            NSApplication.shared.touchBar = nil
            hideHostWindow()
            lastPresentationLogToolID = nil
            presentationKey = nil
            fileLog("Touch Bar cleared")
            return
        }

        guard let waitingTool else {
            return
        }

        let nextPresentationKey = TouchBarPresentationKey(tool: waitingTool)
        if presentationKey == nextPresentationKey {
            showHostWindow()
            return
        }

        presentationKey = nextPresentationKey
        choiceItems = Dictionary(
            uniqueKeysWithValues: waitingTool.choices.prefix(4).map { choice in
                (Item.choice(for: waitingTool, choice: choice), (waitingTool, choice))
            }
        )

        var identifiers: [NSTouchBarItem.Identifier] = [
            Item.summary(for: waitingTool),
            .fixedSpaceSmall,
            Item.log(for: waitingTool)
        ]

        if !waitingTool.choices.isEmpty {
            identifiers.append(.fixedSpaceSmall)
            identifiers.append(contentsOf: waitingTool.choices.prefix(4).map { choice in
                Item.choice(for: waitingTool, choice: choice)
            })
        }

        identifiers.append(.flexibleSpace)
        identifiers.append(Item.activate(for: waitingTool))

        touchBar.defaultItemIdentifiers = identifiers
        touchBar.principalItemIdentifier = Item.log(for: waitingTool)
        NSApplication.shared.touchBar = touchBar
        showHostWindow()

        if lastPresentationLogToolID != waitingTool.id {
            lastPresentationLogToolID = waitingTool.id
            logTouchBarPresentation(for: waitingTool)
        }

        fileLog("Touch Bar preview refreshed: \(waitingTool.name) identifiers=\(identifiers.map(\.rawValue).joined(separator: ","))")
    }

    private func showHostWindow() {
        if hostWindow == nil {
            let view = TouchBarHostView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
            view.touchBar = touchBar
            hostView = view

            let window = TouchBarHostWindow(
                contentRect: NSRect(x: -10_000, y: -10_000, width: 1, height: 1),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.contentView = view
            window.touchBar = touchBar
            window.level = .floating
            window.isOpaque = false
            window.backgroundColor = .clear
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
            window.isReleasedWhenClosed = false
            hostWindow = window
        }

        hostView?.touchBar = touchBar
        hostWindow?.touchBar = touchBar
        hostWindow?.orderFrontRegardless()
        guard NSApplication.shared.isActive else {
            return
        }

        hostWindow?.makeKeyAndOrderFront(nil)
        _ = hostWindow?.makeFirstResponder(hostView)
    }

    private func hideHostWindow() {
        hostWindow?.orderOut(nil)
    }

    private func logTouchBarPresentation(for tool: ToolInfo) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard let self, self.currentTool?.id == tool.id else {
                return
            }

            let isKeyWindow = self.hostWindow.map { NSApplication.shared.keyWindow === $0 } ?? false
            let isFirstResponder = self.hostWindow?.firstResponder === self.hostView
            fileLog(
                "Touch Bar status: \(tool.name) visible=\(self.touchBar.isVisible) keyWindow=\(isKeyWindow) firstResponder=\(isFirstResponder)"
            )
        }
    }

    nonisolated func touchBar(
        _ touchBar: NSTouchBar,
        makeItemForIdentifier identifier: NSTouchBarItem.Identifier
    ) -> NSTouchBarItem? {
        MainActor.assumeIsolated {
            makeItem(for: identifier)
        }
    }

    private func makeItem(for identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard let tool = currentTool else {
            return nil
        }

        if Item.isSummary(identifier) {
            return makeSummaryItem(for: tool)
        }

        if Item.isLog(identifier) {
            return makeLogItem(for: tool)
        }

        if Item.isChoices(identifier) {
            return makeChoicesItem(identifier: identifier, for: tool)
        }

        if Item.isActivate(identifier) {
            return NSButtonTouchBarItem(
                identifier: identifier,
                title: "Open",
                target: self,
                action: #selector(activateCurrentTool(_:))
            )
        }

        if let (tool, choice) = choiceItems[identifier] {
            return makeChoiceButton(identifier: identifier, tool: tool, choice: choice)
        }

        return nil
    }

    private var currentTool: ToolInfo? {
        appState.tools.first { $0.status.isWaiting }
    }

    private func makeSummaryItem(for tool: ToolInfo) -> NSTouchBarItem {
        if let providerIcon = providerIconImage(for: tool) {
            return makeProviderSummaryItem(for: tool, image: providerIcon)
        }

        let item = NSButtonTouchBarItem(
            identifier: Item.summary(for: tool),
            title: tool.name,
            image: image(named: tool.icon),
            target: nil,
            action: nil
        )
        item.bezelColor = .systemOrange
        item.isEnabled = false
        item.customizationLabel = tool.name
        return item
    }

    private func makeProviderSummaryItem(for tool: ToolInfo, image: NSImage) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: Item.summary(for: tool))
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6

        let logo = NSImageView(image: image)
        logo.imageScaling = .scaleProportionallyUpOrDown
        logo.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: tool.name)
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.textColor = .labelColor

        stack.addArrangedSubview(logo)
        stack.addArrangedSubview(title)
        NSLayoutConstraint.activate([
            logo.widthAnchor.constraint(equalToConstant: 24),
            logo.heightAnchor.constraint(equalToConstant: 24)
        ])

        item.view = stack
        item.customizationLabel = tool.name
        return item
    }

    private func providerIconImage(for tool: ToolInfo) -> NSImage? {
        let lowercasedName = tool.name.lowercased()
        let resourceName: String

        if lowercasedName.contains("codex") {
            resourceName = "codex"
        } else if lowercasedName.contains("claude") {
            resourceName = "claude"
        } else if lowercasedName.contains("qoder") {
            resourceName = "qoder"
        } else {
            return nil
        }

        return svgImage(named: resourceName)
    }

    private func svgImage(named name: String) -> NSImage? {
        for url in providerIconURLs(named: name) {
            if let image = NSImage(contentsOf: url) {
                image.size = NSSize(width: 24, height: 24)
                return image
            }
        }

        return nil
    }

    private func providerIconURLs(named name: String) -> [URL] {
        var urls: [URL] = []

        if let appResourceURL = Bundle.main.resourceURL {
            urls.append(
                appResourceURL
                    .appendingPathComponent("ProviderIcons")
                    .appendingPathComponent("\(name).svg")
            )
        }

        urls.append(
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Resources")
                .appendingPathComponent("ProviderIcons")
                .appendingPathComponent("\(name).svg")
        )

        return urls
    }

    private func makeLogItem(for tool: ToolInfo) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: Item.log(for: tool))
        let label = NSTextField(labelWithString: truncate(tool.displayLog, maxLength: 64))
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.textColor = .labelColor
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.frame.size.width = 360
        item.view = label
        item.customizationLabel = "Current request"
        return item
    }

    private func makeChoicesItem(identifier: NSTouchBarItem.Identifier, for tool: ToolInfo) -> NSTouchBarItem {
        let choiceButtons = tool.choices.prefix(4).map { choice in
            let choiceIdentifier = Item.choice(for: tool, choice: choice)
            return makeChoiceButton(identifier: choiceIdentifier, tool: tool, choice: choice)
        }

        let item = NSGroupTouchBarItem(identifier: identifier, items: choiceButtons)
        item.prefersEqualWidths = true
        item.customizationLabel = "Choices"
        return item
    }

    private func makeChoiceButton(
        identifier: NSTouchBarItem.Identifier,
        tool: ToolInfo,
        choice: ToolChoice
    ) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let button = NSButton(
            title: truncate(choice.title, maxLength: 18),
            target: self,
            action: #selector(chooseTouchBarButtonOption(_:))
        )
        button.identifier = NSUserInterfaceItemIdentifier(identifier.rawValue)
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        button.translatesAutoresizingMaskIntoConstraints = false
        item.view = button
        item.customizationLabel = choice.title
        return item
    }

    private func image(named systemName: String) -> NSImage {
        NSImage(systemSymbolName: systemName, accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: "bell.badge", accessibilityDescription: nil)
            ?? NSImage()
    }

    private func truncate(_ value: String, maxLength: Int) -> String {
        guard value.count > maxLength else {
            return value
        }

        return String(value.prefix(maxLength - 1)) + "..."
    }

    @objc private func chooseTouchBarButtonOption(_ sender: NSButton) {
        guard let rawIdentifier = sender.identifier?.rawValue else {
            fileLog("Touch Bar choice ignored: button missing identifier")
            return
        }

        let identifier = NSTouchBarItem.Identifier(rawIdentifier)
        guard let (tool, choice) = choiceItems[identifier] ?? currentChoice(for: identifier) else {
            fileLog("Touch Bar choice ignored: unknown identifier=\(rawIdentifier)")
            return
        }

        fileLog("Touch Bar choice selected: \(tool.name) \(choice.title)")
        appState.choose(choice, for: tool)
        refreshTouchBar()
    }

    private func currentChoice(for identifier: NSTouchBarItem.Identifier) -> (ToolInfo, ToolChoice)? {
        guard let tool = currentTool else {
            return nil
        }

        guard let choice = tool.choices.prefix(4).first(where: { Item.choice(for: tool, choice: $0) == identifier }) else {
            return nil
        }

        return (tool, choice)
    }

    @objc private func activateCurrentTool(_ sender: Any) {
        guard let tool = currentTool else {
            return
        }

        appState.activateTool(tool)
    }
}
