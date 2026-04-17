import Foundation
import SwiftUI
import Testing

@testable import Tajnica_sp

@MainActor
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
    func appleIntelligenceProcessesWithoutExternalAPIKey() async {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel(geminiAPIKey: nil)
        model.updateRawText("Architecture review and bug triage")

        await model.processNote()

        #expect(model.captureErrorMessage == nil)
        #expect(model.draft.candidateEntries.count == 1)
        #expect(model.captureStatusMessage == "Generated 1 candidate entries via Apple Foundation Models.")
    }

    @MainActor
    @Test
    func disabledCloudProviderFallsBackToAppleIntelligenceOnly() async {
        let context = TestContext(provider: .disabled)
        defer { context.cleanup() }

        let model = context.makeAppModel(geminiAPIKey: nil)
        model.updateRawText("Architecture review and bug triage")

        await model.processNote()

        #expect(model.captureErrorMessage == nil)
        #expect(model.draft.candidateEntries.count == 1)
        #expect(model.captureStatusMessage == "Generated 1 candidate entries via Apple Foundation Models.")
    }

    @MainActor
    @Test
    func disabledCloudProviderShowsClearConfigurationErrorWhenAppleIntelligenceIsOff() async {
        let context = TestContext(provider: .disabled, appleIntelligenceEnabled: false)
        defer { context.cleanup() }

        let model = context.makeAppModel(geminiAPIKey: nil)
        model.updateRawText("Architecture review and bug triage")

        await model.processNote()

        #expect(
            model.captureErrorMessage
                == "Enable Apple Intelligence or choose a cloud AI provider in Settings before continuing."
        )
    }

    @MainActor
    @Test
    func externalProviderFallsBackToAppleIntelligenceWhenUnavailable() async {
        let context = TestContext()
        defer { context.cleanup() }

        let appleService = LLMServiceStub(response: LLMServiceStub.defaultResponse)
        let geminiService = LLMServiceStub(
            response: LLMServiceStub.defaultResponse,
            extractError: PlannerServiceError.api(statusCode: 503, message: "Service unavailable")
        )
        let model = context.makeAppModel(
            appleService: appleService,
            geminiService: geminiService
        )
        model.updateRawText("Bug fixes and a planning session")

        await model.processNote()

        #expect(model.captureErrorMessage == nil)
        #expect(
            model.captureStatusMessage
                == "Generated 1 candidate entries via Apple Foundation Models after Google Gemini was unavailable."
        )
    }

    @MainActor
    @Test
    func appleIntelligenceAvailabilityLoadsAutomaticallyForSettings() {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel(geminiAPIKey: nil)

        let isAvailable = model.refreshAppleIntelligenceAvailability()

        #expect(isAvailable)
        #expect(model.appleIntelligenceAvailability == .available)
        #expect(model.appleIntelligenceResult == nil)
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
        #expect(model.captureStatusMessage?.contains("Saved 1 entries to \(AppConfiguration.displayName) Storage") == true)
    }

    @MainActor
    @Test
    func submitEntriesStoresDataEvenWithoutExternalTracker() async throws {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel()
        model.updateRawText("Internal planning")

        await model.processNote()
        await model.submitEntries()

        let snapshot = try context.persistenceController.repository.loadSnapshot(currentDay: context.day)

        #expect(snapshot.storedEntries.count == 1)
        #expect(snapshot.storedEntries.first?.description == "Deep work")
        #expect(model.captureStatusMessage == "Saved 1 entries to \(AppConfiguration.displayName) Storage.")
    }

    @MainActor
    @Test
    func submitEntriesLinksStoredEntriesBackToTheOriginatingDiaryPrompt() async throws {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel(togglToken: "token")
        model.updateRawText("Client implementation")

        await model.processNote()
        let prompt = try #require(model.diaryPromptHistory.last)

        await model.submitEntries()

        let linkedEntries = model.latestStoredEntries(for: prompt.id)

        #expect(linkedEntries.count == 1)
        #expect(linkedEntries.first?.diaryPromptRecordID == prompt.id)
        #expect(linkedEntries.first?.description == "Deep work")
    }

    @MainActor
    @Test
    func exportCanEmitTogglPayloadsFromStoredEntries() async throws {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel(togglToken: "token")
        model.updateRawText("Client implementation")

        await model.processNote()
        await model.submitEntries()
        let exportDay = try #require(model.storedEntries.first?.date)

        let export = try model.prepareAppStorageExport(
            format: .toggl,
            startDate: exportDay,
            endDate: exportDay
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(
            AppStorageExportEnvelope<TogglAppStorageExportEntry>.self,
            from: export.document.data
        )

        #expect(payload.format == .toggl)
        #expect(payload.entries.count == 1)
        #expect(payload.entries.first?.workspaceID == 1)
        #expect(payload.entries.first?.request.description == "Deep work")
    }

    @MainActor
    @Test
    func textDraftSyncIsDeferredUntilFlushed() async throws {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel()
        model.updateRawText("Draft that should not sync immediately")

        let pendingSnapshot = try context.persistenceController.repository.loadSnapshot(currentDay: context.day)
        #expect(pendingSnapshot.draft == nil)

        await model.handleScenePhaseChange(.background)

        let flushedSnapshot = try context.persistenceController.repository.loadSnapshot(currentDay: context.day)
        #expect(flushedSnapshot.draft?.note.rawText == "Draft that should not sync immediately")
    }

    @MainActor
    @Test
    func intentFacadeAppendsToCurrentDraft() async throws {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel()
        let facade = PlannerIntentFacade(appModel: model)

        let message = try await facade.appendToCurrentDraft("Morning standup and planning")

        #expect(model.draft.note.rawText == "Morning standup and planning")
        #expect(message.contains("Added to today's Planner draft."))
        #expect(message.contains("there are no candidate entries yet"))
    }

    @MainActor
    @Test
    func intentFacadeAddsManualDraftEntry() async throws {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel()
        let facade = PlannerIntentFacade(appModel: model)
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(byAdding: .hour, value: 9, to: context.day) ?? context.day
        let stop = calendar.date(byAdding: .hour, value: 10, to: context.day) ?? context.day

        let message = try await facade.addCurrentDraftEntry(
            description: "Bug fixing",
            start: start,
            stop: stop
        )

        #expect(model.draft.candidateEntries.count == 1)
        #expect(model.draft.candidateEntries.first?.description == "Bug fixing")
        #expect(message.contains("Added draft entry \"Bug fixing\""))
        #expect(message.contains("there is 1 candidate entry"))
    }

    @MainActor
    @Test
    func intentFacadeUpdatesExistingDraftEntry() async throws {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel()
        let facade = PlannerIntentFacade(appModel: model)
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(byAdding: .hour, value: 9, to: context.day) ?? context.day
        let stop = calendar.date(byAdding: .hour, value: 10, to: context.day) ?? context.day
        model.addDraftEntry(description: "Bug fixing", start: start, stop: stop)

        let updatedStart = calendar.date(byAdding: .hour, value: 10, to: context.day) ?? context.day
        let updatedStop = calendar.date(byAdding: .hour, value: 11, to: context.day) ?? context.day
        let entryID = try #require(model.draft.candidateEntries.first?.id)

        let message = try await facade.updateCurrentDraftEntry(
            id: entryID,
            description: "Code review",
            start: updatedStart,
            stop: updatedStop
        )

        let updatedEntry = try #require(model.draft.candidateEntries.first)
        let expectedStart = LocalTimeParser.shift(updatedStart, to: updatedEntry.date, in: .autoupdatingCurrent)
        let expectedStop = LocalTimeParser.shift(updatedStop, to: updatedEntry.date, in: .autoupdatingCurrent)
        #expect(updatedEntry.description == "Code review")
        #expect(updatedEntry.start == expectedStart)
        #expect(updatedEntry.stop == expectedStop)
        #expect(message.contains("Updated draft entry \"Code review\""))
    }

    @MainActor
    @Test
    func intentFacadeDeletesExistingDraftEntry() async throws {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel()
        let facade = PlannerIntentFacade(appModel: model)
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(byAdding: .hour, value: 9, to: context.day) ?? context.day
        let stop = calendar.date(byAdding: .hour, value: 10, to: context.day) ?? context.day
        model.addDraftEntry(description: "Bug fixing", start: start, stop: stop)

        let entryID = try #require(model.draft.candidateEntries.first?.id)
        let message = try await facade.deleteCurrentDraftEntry(id: entryID)

        #expect(model.draft.candidateEntries.isEmpty)
        #expect(message.contains("Deleted draft entry \"Bug fixing\""))
    }

    @Test
    func plannerDeepLinkRoundTripsReviewEntry() {
        let entryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
        let url = PlannerDeepLink.review(entryID: entryID).url

        #expect(PlannerDeepLink(url: url) == .review(entryID: entryID))
    }

    @MainActor
    @Test
    func appModelConsumesPendingReviewEntryAfterDeepLink() throws {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel()
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(byAdding: .hour, value: 9, to: context.day) ?? context.day
        let stop = calendar.date(byAdding: .hour, value: 10, to: context.day) ?? context.day
        model.addDraftEntry(description: "Bug fixing", start: start, stop: stop)

        let entryID = try #require(model.draft.candidateEntries.first?.id)
        model.handleIncomingURL(PlannerDeepLink.review(entryID: entryID).url)

        #expect(model.selectedTab == .review)
        #expect(model.consumePendingReviewEntryIfAvailable()?.id == entryID)
        #expect(model.consumePendingReviewEntryIfAvailable() == nil)
    }

    @MainActor
    @Test
    func intentFacadeRejectsSubmissionWithoutEntries() async {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel()
        let facade = PlannerIntentFacade(appModel: model)

        await #expect(throws: PlannerIntentError(message: "There are no draft entries to submit.")) {
            _ = try await facade.submitCurrentDraft()
        }
    }
}

@MainActor
private struct TestContext {
    let applicationName = "PlannerTests.\(UUID().uuidString)"
    let day = TestSupport.selectedDay()
    let preferencesStore: PreferencesStore
    let persistenceController: PlannerPersistenceController

    init(provider: LLMProvider = .gemini, appleIntelligenceEnabled: Bool = true) {
        let defaults = UserDefaults(suiteName: applicationName)!
        defaults.removePersistentDomain(forName: applicationName)

        let preferencesStore = PreferencesStore(userDefaults: defaults)
        preferencesStore.selectedLLMProvider = provider
        preferencesStore.isAppleIntelligenceEnabled = appleIntelligenceEnabled
        self.preferencesStore = preferencesStore
        self.persistenceController = try! PlannerPersistenceController.inMemory()
    }

    func makeAppModel(
        togglToken: String = "",
        geminiAPIKey: String? = "demo-key",
        claudeAPIKey: String? = nil,
        openAIAPIKey: String? = nil,
        appleService: LLMServiceStub = LLMServiceStub(response: LLMServiceStub.defaultResponse),
        geminiService: LLMServiceStub = LLMServiceStub(response: LLMServiceStub.defaultResponse),
        claudeService: LLMServiceStub = LLMServiceStub(response: LLMServiceStub.defaultResponse),
        openAIService: LLMServiceStub = LLMServiceStub(response: LLMServiceStub.defaultResponse)
    ) -> PlannerAppModel {
        var keychainValues: [KeychainKey: String] = [:]
        if let geminiAPIKey {
            keychainValues[.geminiAPIKey] = geminiAPIKey
        }
        if let claudeAPIKey {
            keychainValues[.claudeAPIKey] = claudeAPIKey
        }
        if let openAIAPIKey {
            keychainValues[.openAIAPIKey] = openAIAPIKey
        }
        if !togglToken.isEmpty {
            keychainValues[.togglAPIToken] = togglToken
        }

        let keychainStore = KeychainStoreStub(values: keychainValues)
        let togglService = TogglServiceStub()
        let clockifyService = ClockifyServiceStub()
        let harvestService = HarvestServiceStub()

        return PlannerAppModel(
            preferencesStore: preferencesStore,
            syncRepository: persistenceController.repository,
            storageSyncMode: persistenceController.syncMode,
            keychainStore: keychainStore,
            llmRouter: LLMServiceRouter(
                appleFoundationService: appleService,
                geminiService: geminiService,
                claudeService: claudeService,
                openAIService: openAIService
            ),
            togglService: togglService,
            clockifyService: clockifyService,
            harvestService: harvestService,
            timeZone: TestSupport.timeZone
        )
    }

    func cleanup() {
        UserDefaults(suiteName: applicationName)?.removePersistentDomain(forName: applicationName)

        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let appDirectory = baseDirectory.appendingPathComponent(applicationName, isDirectory: true)
        try? FileManager.default.removeItem(at: appDirectory)
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

private struct LLMServiceStub: LLMServicing, AppleIntelligenceAvailabilityChecking {
    static let defaultResponse = GeminiExtractionResponse(
        entries: [
            .init(
                dateLocal: nil,
                startLocal: "09:00",
                stopLocal: "10:00",
                description: "Deep work",
                togglWorkspaceName: nil,
                togglProjectName: nil,
                clockifyWorkspaceName: nil,
                clockifyProjectName: nil,
                harvestAccountName: nil,
                harvestProjectName: nil,
                harvestTaskName: nil,
                tags: [],
                billable: nil
            )
        ],
        assumptions: [],
        summary: nil
    )

    let response: GeminiExtractionResponse
    var availabilityError: Error?
    var extractError: Error?
    var testConnectionError: Error?
    var polishError: Error?
    var testStatus = "ok"
    var polishedText: String?

    func checkAppleIntelligenceAvailability() throws {
        if let availabilityError {
            throw availabilityError
        }
    }

    func extractTimeEntries(
        apiKey: String,
        model: String,
        note: DailyNoteInput,
        timeZone: TimeZone,
        extractionContext: LLMExtractionContext
    ) async throws -> GeminiExtractionResponse {
        if let extractError {
            throw extractError
        }
        return response
    }

    func testConnection(apiKey: String, model: String) async throws -> String {
        if let testConnectionError {
            throw testConnectionError
        }
        return testStatus
    }

    func polishUserContext(apiKey: String, model: String, rawText: String) async throws -> String {
        if let polishError {
            throw polishError
        }
        return polishedText ?? rawText
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
        _ submissions: [StoredTimeEntryRecord.TogglSubmission],
        apiToken: String
    ) async throws -> [TogglCreatedTimeEntryDTO] {
        submissions.enumerated().map { index, submission in
            TogglCreatedTimeEntryDTO(id: index + 1, description: submission.request.description)
        }
    }
}

private struct ClockifyServiceStub: ClockifyServicing {
    func fetchCurrentUser(apiKey: String) async throws -> ClockifyCurrentUserDTO {
        ClockifyCurrentUserDTO(
            id: "1",
            name: "Clockify User",
            email: "clockify@example.com",
            activeWorkspace: "workspace-1",
            defaultWorkspace: "workspace-1"
        )
    }

    func fetchWorkspaces(apiKey: String) async throws -> [ClockifyWorkspaceSummary] {
        [ClockifyWorkspaceSummary(id: "workspace-1", name: "Clockify Workspace")]
    }

    func fetchProjects(apiKey: String, workspaceID: String) async throws -> [ClockifyProjectSummary] {
        [ClockifyProjectSummary(id: "clockify-project-1", name: "Client Work", workspaceId: workspaceID)]
    }

    func createTimeEntries(
        _ submissions: [StoredTimeEntryRecord.ClockifySubmission],
        apiKey: String
    ) async throws -> [ClockifyCreatedTimeEntryDTO] {
        submissions.enumerated().map { index, submission in
            ClockifyCreatedTimeEntryDTO(id: "clockify-\(index)", description: submission.request.description)
        }
    }
}

private struct HarvestServiceStub: HarvestServicing {
    func fetchAccounts(accessToken: String) async throws -> [HarvestAccountSummary] {
        [HarvestAccountSummary(id: 7, name: "Harvest Account")]
    }

    func fetchCurrentUser(accessToken: String, accountID: Int) async throws -> HarvestCurrentUserDTO {
        HarvestCurrentUserDTO(id: 1, firstName: "Harvest", lastName: "User", email: "harvest@example.com")
    }

    func fetchProjectAssignments(accessToken: String, accountID: Int) async throws -> [HarvestProjectSummary] {
        [
            HarvestProjectSummary(
                id: 12,
                name: "Client Work",
                taskAssignments: [HarvestTaskSummary(id: 18, name: "Implementation")]
            )
        ]
    }

    func createTimeEntries(
        _ submissions: [StoredTimeEntryRecord.HarvestSubmission],
        accessToken: String
    ) async throws -> [HarvestCreatedTimeEntryDTO] {
        submissions.enumerated().map { index, submission in
            HarvestCreatedTimeEntryDTO(id: index + 1, notes: submission.timestampRequest.notes)
        }
    }
}
