import SwiftUI
import CodexReminderCore

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if waitingTools.isEmpty && runningTools.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        if !waitingTools.isEmpty {
                            ForEach(waitingTools) { tool in
                                ToolRow(tool: tool, onChoice: { choice in
                                    appState.choose(choice, for: tool)
                                }, onActivate: {
                                    appState.activateTool(tool)
                                })
                            }
                        }

                        if !runningTools.isEmpty {
                            sectionHeader("Running", color: .green)
                            ForEach(runningTools) { tool in
                                ToolRow(tool: tool, onChoice: { choice in
                                    appState.choose(choice, for: tool)
                                }, onActivate: {
                                    appState.activateTool(tool)
                                })
                            }
                        }
                    }
                    .padding(12)
                }
                .frame(maxHeight: 400)
            }

            Divider()

            footerView
        }
        .frame(width: 320)
    }

    private var waitingTools: [ToolInfo] {
        appState.tools.filter { $0.status.isWaiting }
    }

    private var runningTools: [ToolInfo] {
        appState.tools.filter { !$0.status.isWaiting && $0.status != .idle }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundColor(.green)
            Text("All clear")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("No AI tools need attention")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    private func sectionHeader(_ title: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Spacer()
        }
    }

    private var footerView: some View {
        HStack {
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(12)
    }
}

struct ToolRow: View {
    let tool: ToolInfo
    let onChoice: (ToolChoice) -> Void
    let onActivate: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ProviderIconView(tool: tool)
                .frame(width: 24, height: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(tool.displayMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let log = tool.log, !log.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(log)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                if let cwd = tool.workingDirectory {
                    Text(shortenPath(cwd))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .opacity(0.7)
                }
                if !tool.choices.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(tool.choices.prefix(4)) { choice in
                            Button(choice.title) {
                                onChoice(choice)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.top, 4)
                }
            }

            Spacer()

            Button(action: onActivate) {
                Image(systemName: "arrow.up.forward.square")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(8)
    }

    private func shortenPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

struct ProviderIconView: View {
    let tool: ToolInfo

    var body: some View {
        if let image = providerImage {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: tool.icon)
                .font(.title3)
                .foregroundColor(tool.status.isWaiting ? .orange : .green)
        }
    }

    private var providerImage: NSImage? {
        guard let providerName else {
            return nil
        }

        for url in providerIconURLs(named: providerName) {
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }

        return nil
    }

    private func providerIconURLs(named name: String) -> [URL] {
        var urls: [URL] = []

        if let bundleURL = Bundle.main.url(
            forResource: name,
            withExtension: "svg",
            subdirectory: "ProviderIcons"
        ) {
            urls.append(bundleURL)
        }

        if let resourceURL = Bundle.main.resourceURL {
            urls.append(
                resourceURL
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

    private var providerName: String? {
        let name = tool.name.lowercased()
        if name.contains("codex") {
            return "codex"
        }
        if name.contains("claude") {
            return "claude"
        }
        if name.contains("qoder") {
            return "qoder"
        }
        return nil
    }
}
