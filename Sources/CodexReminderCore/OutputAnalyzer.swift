import Foundation

public enum OutputAnalyzer {

    public struct AnalysisResult: Equatable {
        public let hasAuthKeywords: Bool
        public let hasQuestionMark: Bool
        public let matchedKeywords: [String]

        public init(hasAuthKeywords: Bool, hasQuestionMark: Bool, matchedKeywords: [String]) {
            self.hasAuthKeywords = hasAuthKeywords
            self.hasQuestionMark = hasQuestionMark
            self.matchedKeywords = matchedKeywords
        }
    }

    public static let codexAuthKeywords = [
        "Do you want to proceed?",
        "(y/n)",
        "approve",
        "Allow"
    ]

    public static let claudeAuthKeywords = [
        "Do you want to",
        "Allow",
        "Deny",
        "permission"
    ]

    public static let qoderAuthKeywords = [
        "approv",
        "Allow",
        "permission",
        "Do you want"
    ]

    public static func analyze(output: String, keywords: [String]) -> AnalysisResult {
        var matched: [String] = []
        for keyword in keywords {
            if output.contains(keyword) {
                matched.append(keyword)
            }
        }
        return AnalysisResult(
            hasAuthKeywords: !matched.isEmpty,
            hasQuestionMark: output.contains("?"),
            matchedKeywords: matched
        )
    }

    public static func determineStatus(
        output: String?,
        isProcessSleeping: Bool,
        authKeywords: [String]
    ) -> ToolStatus {
        if let output = output {
            let result = analyze(output: output, keywords: authKeywords)
            if result.hasAuthKeywords {
                return .waitingForAuth(message: "Waiting for approval")
            }
            if result.hasQuestionMark && isProcessSleeping {
                return .waitingForInput(message: "Waiting for user input")
            }
        }

        if isProcessSleeping {
            return .waitingForInput(message: "Waiting for input")
        }

        return .running
    }
}
