import Foundation

enum AppConfiguration {
    static let appName = "Planner"
    static let createdWith = "Planner"
    static let defaultGeminiModel = "gemini-2.5-flash"
    static let defaultClaudeModel = "claude-sonnet-4-20250514"
    static let defaultOpenAIModel = "gpt-4o"
    static let longEntryWarningThreshold: TimeInterval = 4 * 60 * 60
    static let largeGapWarningThreshold: TimeInterval = 2 * 60 * 60
}
