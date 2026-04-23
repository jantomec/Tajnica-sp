import Foundation

/// Accessor for smoke-test credentials supplied via the test scheme's
/// environment variables. Each property returns `nil` when the corresponding
/// variable is absent or blank; live smoke tests gate their execution on that
/// so the normal suite still passes on machines without credentials.
enum SmokeCredentials {
    static var geminiAPIKey: String? { value(for: "TAJNICA_SMOKE_GEMINI_API_KEY") }
    static var togglAPIToken: String? { value(for: "TAJNICA_SMOKE_TOGGL_TOKEN") }

    static let geminiDefaultModel = "gemini-2.5-flash"

    private static func value(for name: String) -> String? {
        guard let raw = ProcessInfo.processInfo.environment[name] else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
