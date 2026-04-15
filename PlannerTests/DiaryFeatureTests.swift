import Foundation
import Testing

@testable import Planner

struct DiaryFeatureTests {
    @Test
    func diaryStoreRoundTripsRecords() throws {
        let context = TestContext()
        defer { context.cleanup() }

        let store = DiaryStore(applicationName: context.applicationName)
        let records = [
            DiaryPromptRecord(day: context.day, rawText: "Morning standup", createdAt: context.day.addingTimeInterval(60))
        ]

        try store.save(records)

        let loaded = try store.loadPromptHistory()

        #expect(loaded == records)
    }

    @Test
    func feedItemsInsertDateSeparatorsAtDayBoundaries() {
        let earlierDay = TestSupport.selectedDay(year: 2026, month: 4, day: 2)
        let laterDay = TestSupport.selectedDay(year: 2026, month: 4, day: 3)
        let first = DiaryPromptRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            day: earlierDay,
            rawText: "Earlier",
            createdAt: earlierDay.addingTimeInterval(60)
        )
        let second = DiaryPromptRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            day: earlierDay,
            rawText: "Later same day",
            createdAt: earlierDay.addingTimeInterval(120)
        )
        let third = DiaryPromptRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            day: laterDay,
            rawText: "Newest day",
            createdAt: laterDay.addingTimeInterval(60)
        )

        let items = DiaryFeedItem.makeFeedItems(from: [first, third, second])

        #expect(items == [
            .dateSeparator(laterDay),
            .prompt(third),
            .dateSeparator(earlierDay),
            .prompt(second),
            .prompt(first)
        ])
    }

    @MainActor
    @Test
    func processNoteArchivesPromptAndSkipsExactSameDayDuplicate() async throws {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel()
        model.updateRawText("Deep work and a retro")

        await model.processNote()
        let firstArchive = model.diaryPromptHistory

        #expect(firstArchive.count == 1)
        #expect(firstArchive[0].rawText == "Deep work and a retro")
        #expect(firstArchive[0].day == model.draft.note.date)

        await model.processNote(replacingExistingEntries: true)

        #expect(model.diaryPromptHistory.count == 1)
    }

    @MainActor
    @Test
    func clearDraftKeepsArchivedPrompts() async {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel()
        model.updateRawText("Planning and code review")

        await model.processNote()
        model.clearDraft()

        #expect(model.diaryPromptHistory.count == 1)
        #expect(model.draft.note.rawText.isEmpty)
    }

    @MainActor
    @Test
    func submitEntriesClearsDraftButKeepsDiaryHistory() async {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel(togglToken: "token")
        model.updateRawText("Support and bug fixes")

        await model.processNote()
        await model.submitEntries()

        #expect(model.diaryPromptHistory.count == 1)
        #expect(model.draft.note.rawText.isEmpty)
        #expect(model.captureStatusMessage?.contains("Submitted 1 entries") == true)
    }
}

private struct TestContext {
    let applicationName = "PlannerTests.\(UUID().uuidString)"
    let day = TestSupport.selectedDay()

    func makeAppModel(togglToken: String = "") -> PlannerAppModel {
        let preferencesStore = PreferencesStore(userDefaults: makeUserDefaults())
        let keychainStore = KeychainStoreStub(
            values: [
                .geminiAPIKey: "demo-key",
                .togglAPIToken: togglToken
            ]
        )
        let llmService = LLMServiceStub(
            response: GeminiExtractionResponse(
                entries: [
                    .init(
                        dateLocal: nil,
                        startLocal: "09:00",
                        stopLocal: "10:00",
                        description: "Deep work",
                        projectName: nil,
                        tags: [],
                        billable: nil
                    )
                ],
                assumptions: [],
                summary: nil
            )
        )
        let togglService = TogglServiceStub()

        return PlannerAppModel(
            preferencesStore: preferencesStore,
            draftStore: DraftStore(applicationName: applicationName),
            diaryStore: DiaryStore(applicationName: applicationName),
            keychainStore: keychainStore,
            llmRouter: LLMServiceRouter(
                geminiService: llmService,
                claudeService: llmService,
                openAIService: llmService
            ),
            togglService: togglService,
            timeZone: TestSupport.timeZone
        )
    }

    func cleanup() {
        makeUserDefaults().removePersistentDomain(forName: applicationName)

        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let appDirectory = baseDirectory.appendingPathComponent(applicationName, isDirectory: true)
        try? FileManager.default.removeItem(at: appDirectory)
    }

    private func makeUserDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: applicationName)!
        defaults.removePersistentDomain(forName: applicationName)
        return defaults
    }
}

private final class KeychainStoreStub: KeychainStoring {
    private var values: [KeychainKey: String]

    init(values: [KeychainKey: String] = [:]) {
        self.values = values
    }

    func string(for key: KeychainKey) -> String? {
        values[key]
    }

    func set(_ value: String, for key: KeychainKey) {
        values[key] = value
    }

    func removeValue(for key: KeychainKey) {
        values.removeValue(forKey: key)
    }
}

private struct LLMServiceStub: LLMServicing {
    let response: GeminiExtractionResponse

    func extractTimeEntries(
        apiKey: String,
        model: String,
        note: DailyNoteInput,
        timeZone: TimeZone,
        userContext: String?,
        availableProjects: [String]
    ) async throws -> GeminiExtractionResponse {
        response
    }

    func testConnection(apiKey: String, model: String) async throws -> String {
        "ok"
    }

    func polishUserContext(apiKey: String, model: String, rawText: String) async throws -> String {
        rawText
    }
}

private struct TogglServiceStub: TogglServicing {
    func fetchCurrentUser(apiToken: String) async throws -> TogglCurrentUserDTO {
        TogglCurrentUserDTO(id: 1, fullname: "Test User", email: "user@example.com")
    }

    func fetchWorkspaces(apiToken: String) async throws -> [WorkspaceSummary] {
        [WorkspaceSummary(id: 1, name: "Workspace")]
    }

    func fetchProjects(apiToken: String, workspaceID: Int) async throws -> [ProjectSummary] {
        []
    }

    func createTimeEntries(
        _ payloads: [TogglTimeEntryCreateRequest],
        apiToken: String,
        workspaceID: Int
    ) async throws -> [TogglCreatedTimeEntryDTO] {
        payloads.enumerated().map { index, payload in
            TogglCreatedTimeEntryDTO(id: index + 1, description: payload.description)
        }
    }
}
