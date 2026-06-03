import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("pollingInterval") private var pollingInterval: Double = 2.0
    @AppStorage("showNotifications") private var showNotifications: Bool = true
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("monitorCodex") private var monitorCodex: Bool = true
    @AppStorage("monitorClaudeCode") private var monitorClaudeCode: Bool = true
    @AppStorage("monitorQoder") private var monitorQoder: Bool = true

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }
            toolsTab
                .tabItem { Label("Tools", systemImage: "wrench") }
        }
        .frame(width: 400, height: 280)
        .padding()
    }

    private var generalTab: some View {
        Form {
            Toggle("Launch at Login", isOn: $launchAtLogin)

            Toggle("Show Notifications", isOn: $showNotifications)
                .onChange(of: showNotifications) { newValue in
                    appState.showNotifications = newValue
                }

            HStack {
                Text("Check interval:")
                Slider(value: $pollingInterval, in: 1...10, step: 0.5)
                Text("\(pollingInterval, specifier: "%.1f")s")
                    .monospacedDigit()
                    .frame(width: 40)
            }
        }
        .padding()
    }

    private var toolsTab: some View {
        Form {
            Section("Monitored Tools") {
                Toggle("Codex (OpenAI)", isOn: $monitorCodex)
                Toggle("Claude Code (Anthropic)", isOn: $monitorClaudeCode)
                Toggle("Qoder CLI", isOn: $monitorQoder)
            }

            Section("Detection Keywords") {
                Text("The app monitors process names and terminal output for patterns indicating waiting state.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}
