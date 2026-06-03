import Foundation

public enum ToolStatus: Equatable, Sendable {
    case idle
    case running
    case waitingForInput(message: String)
    case waitingForAuth(message: String)

    public var isWaiting: Bool {
        switch self {
        case .waitingForInput, .waitingForAuth:
            return true
        default:
            return false
        }
    }

    public var displayMessage: String {
        switch self {
        case .waitingForInput(let msg): return msg
        case .waitingForAuth(let msg): return msg
        case .running: return "Running..."
        case .idle: return "Idle"
        }
    }
}
