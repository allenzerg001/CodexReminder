import Foundation

public struct ToolChoice: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public let title: String
    public let value: String

    public init(id: String, title: String, value: String) {
        self.id = id
        self.title = title
        self.value = value
    }
}
