// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodexReminder",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "CodexReminderCore",
            path: "Sources/CodexReminderCore"
        ),
        .executableTarget(
            name: "CodexReminder",
            dependencies: ["CodexReminderCore"],
            path: "Sources/CodexReminder",
            resources: [.process("../../Resources")]
        ),
        .executableTarget(
            name: "CodexReminderHook",
            dependencies: ["CodexReminderCore"],
            path: "Sources/CodexReminderHook"
        ),
        .testTarget(
            name: "CodexReminderTests",
            dependencies: ["CodexReminderCore"],
            path: "Tests/CodexReminderTests"
        )
    ]
)
