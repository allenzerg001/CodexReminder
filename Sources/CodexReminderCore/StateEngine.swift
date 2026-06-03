import Foundation

public enum StateEngine {

    public struct Snapshot: Equatable {
        public let tools: [ToolInfo]
        public let isAnimating: Bool
        public let newlyWaitingIds: Set<String>

        public init(tools: [ToolInfo], isAnimating: Bool, newlyWaitingIds: Set<String>) {
            self.tools = tools
            self.isAnimating = isAnimating
            self.newlyWaitingIds = newlyWaitingIds
        }
    }

    public static func computeSnapshot(
        previousTools: [ToolInfo],
        detectedTools: [ToolInfo]
    ) -> Snapshot {
        let previouslyWaiting = Set(previousTools.filter { $0.status.isWaiting }.map { $0.id })
        let nowWaiting = Set(detectedTools.filter { $0.status.isWaiting }.map { $0.id })
        let newlyWaiting = nowWaiting.subtracting(previouslyWaiting)

        return Snapshot(
            tools: detectedTools,
            isAnimating: !nowWaiting.isEmpty,
            newlyWaitingIds: newlyWaiting
        )
    }

    public static func toolsNeedingAttention(_ tools: [ToolInfo]) -> [ToolInfo] {
        tools.filter { $0.status.isWaiting }
    }

    public static func runningTools(_ tools: [ToolInfo]) -> [ToolInfo] {
        tools.filter { !$0.status.isWaiting && $0.status != .idle }
    }
}
