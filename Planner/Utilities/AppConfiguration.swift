import Foundation

enum AppConfiguration {
    // Keep legacy storage namespaces stable; this is not the user-facing app name.
    static let appName = "Planner"
    static let displayName = "Tajnica s.p."
    static let cloudKitContainerIdentifier = "iCloud.com.jantomec.planner"
    static let createdWith = displayName
    static let defaultAppleFoundationModel = "on-device"
    static let defaultGeminiModel = "gemini-2.5-flash"
    static let defaultClaudeModel = "claude-sonnet-4-20250514"
    static let defaultOpenAIModel = "gpt-4o"
    static let draftSyncDebounceInterval: Duration = .seconds(30)
    static let longEntryWarningThreshold: TimeInterval = 4 * 60 * 60
    static let largeGapWarningThreshold: TimeInterval = 2 * 60 * 60
}
