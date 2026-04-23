import Foundation
import Testing

@testable import Tajnica_sp

/// Live smoke tests that hit real third-party endpoints using the scheme's
/// `TAJNICA_SMOKE_*` environment variables. Each test is gated on the matching
/// credential, so when an env var is absent the test is skipped and the rest
/// of the suite still passes.
///
/// These tests cost network time and (for Gemini) free-tier quota. Disable
/// individual env vars in the scheme's Test action to turn specific smoke
/// tests off without removing the others.
@MainActor
struct SmokeTests {
    // MARK: - Gemini

    @Test(.enabled(if: SmokeCredentials.geminiAPIKey != nil))
    func geminiConnectionTest_live() async throws {
        let apiKey = try #require(SmokeCredentials.geminiAPIKey)
        let service = GeminiService(httpClient: URLSessionHTTPClient())

        let status = try await service.testConnection(
            apiKey: apiKey,
            model: SmokeCredentials.geminiDefaultModel
        )

        #expect(status.lowercased().contains("ok"))
    }

    @Test(.enabled(if: SmokeCredentials.geminiAPIKey != nil))
    func geminiExtraction_live_returnsUsableResponse() async throws {
        let apiKey = try #require(SmokeCredentials.geminiAPIKey)
        let service = GeminiService(httpClient: URLSessionHTTPClient())

        let day = TestSupport.selectedDay()
        let note = DailyNoteInput(
            date: day,
            rawText: """
            09:00-10:00 morning standup
            10:00-12:00 export fixes
            14:00-15:30 triage and follow-up bugs
            """
        )
        let context = LLMExtractionContext(
            userContext: nil,
            togglWorkspaces: [],
            clockifyWorkspaces: [],
            harvestAccounts: []
        )

        let response = try await service.extractTimeEntries(
            apiKey: apiKey,
            model: SmokeCredentials.geminiDefaultModel,
            note: note,
            timeZone: TestSupport.timeZone,
            extractionContext: context
        )

        #expect(!response.entries.isEmpty, "Gemini should return at least one entry for a three-line note.")
    }

    // MARK: - Toggl

    @Test(.enabled(if: SmokeCredentials.togglAPIToken != nil))
    func togglFetchCurrentUser_live() async throws {
        let apiToken = try #require(SmokeCredentials.togglAPIToken)
        let service = TogglService(httpClient: URLSessionHTTPClient())

        let user = try await service.fetchCurrentUser(apiToken: apiToken)

        #expect(user.id > 0)
        #expect(!(user.email ?? "").isEmpty)
    }

    @Test(.enabled(if: SmokeCredentials.togglAPIToken != nil))
    func togglFetchWorkspaces_live() async throws {
        let apiToken = try #require(SmokeCredentials.togglAPIToken)
        let service = TogglService(httpClient: URLSessionHTTPClient())

        let workspaces = try await service.fetchWorkspaces(apiToken: apiToken)

        #expect(!workspaces.isEmpty, "Dummy Toggl account should expose at least one workspace.")
    }
}
