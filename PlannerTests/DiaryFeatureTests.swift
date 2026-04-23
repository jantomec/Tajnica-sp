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
    func polishUserContextUpdatesContextAndReportsSuccess() async {
        let context = TestContext()
        defer { context.cleanup() }

        let geminiService = LLMServiceStub(
            response: LLMServiceStub.defaultResponse,
            polishedText: "Polished output"
        )

        let model = context.makeAppModel(geminiService: geminiService)
        model.userContext = "raw context"

        await model.polishUserContext()

        #expect(model.userContext == "Polished output")
        #expect(model.polishResult?.isError == false)
        #expect(model.polishResult?.message == "Polished successfully.")
        #expect(model.isPolishingContext == false)
    }

    @MainActor
    @Test
    func polishUserContextFallsBackToAppleIntelligenceWhenPrimaryFails() async {
        let context = TestContext()
        defer { context.cleanup() }

        let appleService = LLMServiceStub(
            response: LLMServiceStub.defaultResponse,
            polishedText: "Apple-polished output"
        )
        let geminiService = LLMServiceStub(
            response: LLMServiceStub.defaultResponse,
            polishError: PlannerServiceError.api(statusCode: 503, message: "Service unavailable")
        )

        let model = context.makeAppModel(
            appleService: appleService,
            geminiService: geminiService
        )
        model.userContext = "raw context"

        await model.polishUserContext()

        #expect(model.userContext == "Apple-polished output")
        #expect(model.polishResult?.isError == false)
        #expect(
            model.polishResult?.message
                == "Polished successfully with Apple Intelligence fallback."
        )
    }

    @MainActor
    @Test
    func polishUserContextReportsConfigurationErrorWhenNoProviderAvailable() async {
        let context = TestContext(provider: .disabled, appleIntelligenceEnabled: false)
        defer { context.cleanup() }

        let model = context.makeAppModel(geminiAPIKey: nil)
        model.userContext = "raw context"

        await model.polishUserContext()

        #expect(model.userContext == "raw context")
        #expect(model.polishResult?.isError == true)
        #expect(
            model.polishResult?.message
                == "Enable Apple Intelligence or choose a cloud AI provider in Settings before continuing."
        )
    }

    @MainActor
    @Test
    func polishUserContextRejectsBlankInput() async {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel()
        model.userContext = ""

        await model.polishUserContext()

        #expect(model.userContext == "")
        #expect(model.polishResult?.isError == true)
        #expect(model.polishResult?.message == "Write something about yourself first.")
    }

    @MainActor
    @Test
    func polishUserContextSurfacesServiceErrorWhenFallbackUnavailable() async {
        let context = TestContext()
        defer { context.cleanup() }

        let geminiService = LLMServiceStub(
            response: LLMServiceStub.defaultResponse,
            polishError: PlannerServiceError.missingCredential("Gemini API key")
        )

        let model = context.makeAppModel(geminiService: geminiService)
        model.userContext = "raw context"

        await model.polishUserContext()

        #expect(model.userContext == "raw context")
        #expect(model.polishResult?.isError == true)
        #expect(model.polishResult?.message == "Gemini API key is missing.")
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
    func submitEntriesPushesToAllConfiguredDestinations() async throws {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel(
            togglToken: "token",
            clockifyToken: "token",
            harvestToken: "token"
        )
        model.updateRawText("Client implementation")

        await model.processNote()

        let entryID = try #require(model.draft.candidateEntries.first?.id)
        model.setHarvestAssignment(id: entryID, accountID: 7, projectID: 12, taskID: 18)

        await model.submitEntries()

        let snapshot = try context.persistenceController.repository.loadSnapshot(currentDay: context.day)
        let storedEntry = try #require(snapshot.storedEntries.first)

        #expect(model.reviewErrorMessage == nil)
        #expect(
            model.captureStatusMessage
                == "Saved 1 entries to \(AppConfiguration.displayName) Storage and submitted them to Toggl, Clockify, and Harvest."
        )
        #expect(storedEntry.toggl?.workspaceID == 1)
        #expect(storedEntry.clockify?.workspaceID == "workspace-1")
        #expect(storedEntry.harvest?.accountID == 7)
        #expect(storedEntry.harvest?.projectID == 12)
        #expect(storedEntry.harvest?.taskID == 18)
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
        #expect(export.filename == expectedExportFilename(format: .toggl, day: exportDay))
    }

    @MainActor
    @Test
    func exportCanEmitClockifyPayloadsFromStoredEntries() async throws {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel(clockifyToken: "token")
        model.updateRawText("Client implementation")

        await model.processNote()
        await model.submitEntries()
        let exportDay = try #require(model.storedEntries.first?.date)

        let export = try model.prepareAppStorageExport(
            format: .clockify,
            startDate: exportDay,
            endDate: exportDay
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(
            AppStorageExportEnvelope<ClockifyAppStorageExportEntry>.self,
            from: export.document.data
        )

        #expect(payload.format == .clockify)
        #expect(payload.entries.count == 1)
        #expect(payload.entries.first?.workspaceID == "workspace-1")
        #expect(payload.entries.first?.request.description == "Deep work")
        #expect(export.filename == expectedExportFilename(format: .clockify, day: exportDay))
    }

    @MainActor
    @Test
    func exportCanEmitHarvestPayloadsFromStoredEntries() async throws {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel(harvestToken: "token")
        model.updateRawText("Client implementation")

        await model.processNote()
        let entryID = try #require(model.draft.candidateEntries.first?.id)
        model.setHarvestAssignment(id: entryID, accountID: 7, projectID: 12, taskID: 18)
        await model.submitEntries()
        let exportDay = try #require(model.storedEntries.first?.date)

        let export = try model.prepareAppStorageExport(
            format: .harvest,
            startDate: exportDay,
            endDate: exportDay
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(
            AppStorageExportEnvelope<HarvestAppStorageExportEntry>.self,
            from: export.document.data
        )

        #expect(payload.format == .harvest)
        #expect(payload.entries.count == 1)
        #expect(payload.entries.first?.accountID == 7)
        #expect(payload.entries.first?.projectID == 12)
        #expect(payload.entries.first?.taskID == 18)
        #expect(payload.entries.first?.timestampRequest.notes == "Deep work")
        #expect(export.filename == expectedExportFilename(format: .harvest, day: exportDay))
    }

    @MainActor
    @Test
    func refreshTimeTrackerConnectionsOnViewLoadRetestsStoredCredentials() async {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel(
            togglToken: "token",
            clockifyToken: "token",
            harvestToken: "token"
        )

        await model.refreshTimeTrackerConnectionsOnViewLoad()

        #expect(model.togglTestResult?.isError == false)
        #expect(model.clockifyTestResult?.isError == false)
        #expect(model.harvestTestResult?.isError == false)
        #expect(model.togglTestResult?.message.contains("Connected as Test User") == true)
        #expect(model.clockifyTestResult?.message.contains("Connected as Clockify User") == true)
        #expect(model.harvestTestResult?.message.contains("Connected as Harvest User") == true)
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
        #expect(message.contains("Added to today's draft."))
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
    func intentFacadeDuplicatesDraftEntry() async throws {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel()
        let facade = PlannerIntentFacade(appModel: model)
        let start = TestSupport.localDate(on: context.day, hour: 9, minute: 0)
        let stop = TestSupport.localDate(on: context.day, hour: 10, minute: 0)
        model.addDraftEntry(description: "Bug fixing", start: start, stop: stop)

        let entryID = try #require(model.draft.candidateEntries.first?.id)
        let message = try await facade.duplicateCurrentDraftEntry(id: entryID)

        #expect(model.draft.candidateEntries.count == 2)
        #expect(message.contains("Duplicated draft entry \"Bug fixing\""))
    }

    @MainActor
    @Test
    func intentFacadeSetsBillableAndTags() async throws {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel()
        let facade = PlannerIntentFacade(appModel: model)
        let start = TestSupport.localDate(on: context.day, hour: 9, minute: 0)
        let stop = TestSupport.localDate(on: context.day, hour: 10, minute: 0)
        model.addDraftEntry(description: "Bug fixing", start: start, stop: stop)

        let entryID = try #require(model.draft.candidateEntries.first?.id)

        let billableMessage = try await facade.setCurrentDraftEntryBillable(id: entryID, billable: true)
        let tagsMessage = try await facade.setCurrentDraftEntryTags(id: entryID, tags: ["client", " review ", "client"])

        let updatedEntry = try #require(model.draft.candidateEntries.first)
        #expect(updatedEntry.billable == true)
        #expect(updatedEntry.tags == ["client", "review"])
        #expect(billableMessage.contains("Marked \"Bug fixing\" as billable"))
        #expect(tagsMessage.contains("#client, #review"))
    }

    @MainActor
    @Test
    func intentFacadeAssignsTogglProjectToDraftEntry() async throws {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel(togglToken: "token")
        let facade = PlannerIntentFacade(appModel: model, startsModelOnUse: true)
        let start = TestSupport.localDate(on: context.day, hour: 9, minute: 0)
        let stop = TestSupport.localDate(on: context.day, hour: 10, minute: 0)
        model.addDraftEntry(description: "Bug fixing", start: start, stop: stop)

        let entryID = try #require(model.draft.candidateEntries.first?.id)
        let message = try await facade.assignTogglProject(entryID: entryID, workspaceID: 1, projectID: 101)

        let updatedEntry = try #require(model.draft.candidateEntries.first)
        #expect(updatedEntry.togglTarget?.workspaceId == 1)
        #expect(updatedEntry.togglTarget?.projectId == 101)
        #expect(updatedEntry.togglTarget?.projectName == "Client Work")
        #expect(message.contains("Assigned Toggl project \"Client Work\""))
    }

    @MainActor
    @Test
    func intentFacadeAssignsClockifyProjectToDraftEntry() async throws {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel(clockifyToken: "token")
        let facade = PlannerIntentFacade(appModel: model, startsModelOnUse: true)
        let start = TestSupport.localDate(on: context.day, hour: 9, minute: 0)
        let stop = TestSupport.localDate(on: context.day, hour: 10, minute: 0)
        model.addDraftEntry(description: "Bug fixing", start: start, stop: stop)

        let entryID = try #require(model.draft.candidateEntries.first?.id)
        let message = try await facade.assignClockifyProject(
            entryID: entryID,
            workspaceID: "workspace-1",
            projectID: "clockify-project-1"
        )

        let updatedEntry = try #require(model.draft.candidateEntries.first)
        #expect(updatedEntry.clockifyTarget?.workspaceId == "workspace-1")
        #expect(updatedEntry.clockifyTarget?.projectId == "clockify-project-1")
        #expect(updatedEntry.clockifyTarget?.projectName == "Client Work")
        #expect(message.contains("Assigned Clockify project \"Client Work\""))
    }

    @MainActor
    @Test
    func intentFacadeAssignsHarvestTaskToDraftEntryAndCanClearIt() async throws {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel(harvestToken: "token")
        let facade = PlannerIntentFacade(appModel: model, startsModelOnUse: true)
        let start = TestSupport.localDate(on: context.day, hour: 9, minute: 0)
        let stop = TestSupport.localDate(on: context.day, hour: 10, minute: 0)
        model.addDraftEntry(description: "Bug fixing", start: start, stop: stop)

        let entryID = try #require(model.draft.candidateEntries.first?.id)
        let assignMessage = try await facade.assignHarvestTask(
            entryID: entryID,
            accountID: 7,
            projectID: 12,
            taskID: 18
        )
        let clearMessage = try await facade.clearTrackerAssignment(entryID: entryID, provider: .harvest)

        let updatedEntry = try #require(model.draft.candidateEntries.first)
        #expect(updatedEntry.harvestTarget == nil)
        #expect(assignMessage.contains("Assigned Harvest task \"Implementation\""))
        #expect(clearMessage.contains("Cleared the Harvest assignment"))
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

    @MainActor
    @Test
    func intentFacadeUsesReleaseNameForTrackerConnectionErrors() async throws {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel()
        let facade = PlannerIntentFacade(appModel: model, startsModelOnUse: true)
        let start = TestSupport.localDate(on: context.day, hour: 9, minute: 0)
        let stop = TestSupport.localDate(on: context.day, hour: 10, minute: 0)
        model.addDraftEntry(description: "Bug fixing", start: start, stop: stop)

        let entryID = try #require(model.draft.candidateEntries.first?.id)

        await #expect(
            throws: PlannerIntentError(message: "Toggl is not connected in \(AppConfiguration.displayName)")
        ) {
            _ = try await facade.assignTogglWorkspace(entryID: entryID, workspaceID: 1)
        }
    }

    // MARK: - Empty Credential Guardrails

    @MainActor
    @Test
    func emptyCredentialsBlockConnectionTestsWithGuardrailMessages() async {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel()

        #expect(model.configuredExternalTimeTrackers.isEmpty)
        #expect(model.hasStoredCredential(for: .toggl) == false)
        #expect(model.hasStoredCredential(for: .clockify) == false)
        #expect(model.hasStoredCredential(for: .harvest) == false)

        await model.testTogglConnection()
        #expect(model.togglTestResult == PlannerAppModel.InlineResult(
            message: "Enter a Toggl API token first.",
            isError: true
        ))
        #expect(model.isTestingToggl == false)

        await model.testClockifyConnection()
        #expect(model.clockifyTestResult == PlannerAppModel.InlineResult(
            message: "Enter a Clockify API key first.",
            isError: true
        ))
        #expect(model.isTestingClockify == false)

        await model.testHarvestConnection()
        #expect(model.harvestTestResult == PlannerAppModel.InlineResult(
            message: "Enter a Harvest access token first.",
            isError: true
        ))
        #expect(model.isTestingHarvest == false)
    }

    @MainActor
    @Test
    func whitespaceOnlyCredentialsAreTreatedAsMissing() async {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel()
        model.updateTogglAPIToken("   ")
        model.updateClockifyAPIToken("\t\n")
        model.updateHarvestAccessToken("  \n  ")

        #expect(model.hasStoredCredential(for: .toggl) == false)
        #expect(model.hasStoredCredential(for: .clockify) == false)
        #expect(model.hasStoredCredential(for: .harvest) == false)
        #expect(model.configuredExternalTimeTrackers.isEmpty)

        await model.testTogglConnection()
        await model.testClockifyConnection()
        await model.testHarvestConnection()

        #expect(model.togglTestResult?.isError == true)
        #expect(model.togglTestResult?.message == "Enter a Toggl API token first.")
        #expect(model.clockifyTestResult?.isError == true)
        #expect(model.clockifyTestResult?.message == "Enter a Clockify API key first.")
        #expect(model.harvestTestResult?.isError == true)
        #expect(model.harvestTestResult?.message == "Enter a Harvest access token first.")
    }

    @MainActor
    @Test
    func submitEntriesSkipsTrackersWithoutCredentialsAndOnlyReportsAppStorage() async {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel()
        model.updateRawText("Internal planning")

        await model.processNote()
        await model.submitEntries()

        #expect(model.reviewErrorMessage == nil)
        #expect(model.captureStatusMessage == "Saved 1 entries to \(AppConfiguration.displayName) Storage.")
        #expect(
            model.submissionDestinationSummary
                == "Submitted entries are always saved in \(AppConfiguration.displayName) Storage. No external tracker is currently connected."
        )
    }

    @MainActor
    @Test
    func refreshTimeTrackerConnectionsOnViewLoadSkipsWhenNoCredentialsStored() async {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel()

        await model.refreshTimeTrackerConnectionsOnViewLoad()

        #expect(model.togglTestResult == nil)
        #expect(model.clockifyTestResult == nil)
        #expect(model.harvestTestResult == nil)
        #expect(model.isTestingToggl == false)
        #expect(model.isTestingClockify == false)
        #expect(model.isTestingHarvest == false)
        #expect(model.togglWorkspaceCatalogs.isEmpty)
        #expect(model.clockifyWorkspaceCatalogs.isEmpty)
        #expect(model.harvestAccountCatalogs.isEmpty)
    }

    @MainActor
    @Test
    func disconnectingTimeTrackerClearsTokenCatalogsAndTestResult() async {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel(
            togglToken: "toggl-token",
            clockifyToken: "clockify-token",
            harvestToken: "harvest-token"
        )

        await model.testTogglConnection()
        await model.testClockifyConnection()
        await model.testHarvestConnection()

        #expect(model.togglTestResult?.isError == false)
        #expect(model.clockifyTestResult?.isError == false)
        #expect(model.harvestTestResult?.isError == false)
        #expect(!model.togglWorkspaceCatalogs.isEmpty)
        #expect(!model.clockifyWorkspaceCatalogs.isEmpty)
        #expect(!model.harvestAccountCatalogs.isEmpty)

        model.disconnectTimeTracker(.toggl)
        model.disconnectTimeTracker(.clockify)
        model.disconnectTimeTracker(.harvest)

        #expect(model.hasStoredCredential(for: .toggl) == false)
        #expect(model.hasStoredCredential(for: .clockify) == false)
        #expect(model.hasStoredCredential(for: .harvest) == false)
        #expect(model.togglTestResult == nil)
        #expect(model.clockifyTestResult == nil)
        #expect(model.harvestTestResult == nil)
        #expect(model.togglWorkspaceCatalogs.isEmpty)
        #expect(model.clockifyWorkspaceCatalogs.isEmpty)
        #expect(model.harvestAccountCatalogs.isEmpty)
    }

    @MainActor
    @Test
    func intentFacadeReportsUnconfiguredClockifyWhenAssigningWorkspace() async throws {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel()
        let facade = PlannerIntentFacade(appModel: model, startsModelOnUse: true)
        let start = TestSupport.localDate(on: context.day, hour: 9, minute: 0)
        let stop = TestSupport.localDate(on: context.day, hour: 10, minute: 0)
        model.addDraftEntry(description: "Bug fixing", start: start, stop: stop)

        let entryID = try #require(model.draft.candidateEntries.first?.id)

        await #expect(
            throws: PlannerIntentError(message: "Clockify is not connected in \(AppConfiguration.displayName)")
        ) {
            _ = try await facade.assignClockifyWorkspace(entryID: entryID, workspaceID: "workspace-1")
        }
    }

    @MainActor
    @Test
    func intentFacadeReportsUnconfiguredHarvestWhenAssigningTask() async throws {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel()
        let facade = PlannerIntentFacade(appModel: model, startsModelOnUse: true)
        let start = TestSupport.localDate(on: context.day, hour: 9, minute: 0)
        let stop = TestSupport.localDate(on: context.day, hour: 10, minute: 0)
        model.addDraftEntry(description: "Bug fixing", start: start, stop: stop)

        let entryID = try #require(model.draft.candidateEntries.first?.id)

        await #expect(
            throws: PlannerIntentError(message: "Harvest is not connected in \(AppConfiguration.displayName)")
        ) {
            _ = try await facade.assignHarvestTask(entryID: entryID, accountID: 7, projectID: 12, taskID: 18)
        }
    }

    // MARK: - Successful Connection Tests Fetch Reference Data

    @MainActor
    @Test
    func successfulTogglConnectionTestLoadsCatalogsAndPersistsResolvedWorkspace() async {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel(togglToken: "toggl-token")
        await model.testTogglConnection()

        #expect(model.togglTestResult?.isError == false)
        #expect(model.togglWorkspaceCatalogs.count == 1)
        #expect(model.togglWorkspaceCatalogs.first?.workspace.id == 1)
        #expect(model.togglWorkspaceCatalogs.first?.workspace.name == "Workspace")
        #expect(model.togglWorkspaceCatalogs.first?.projects.first?.id == 101)
        #expect(model.resolvedWorkspace?.id == 1)
        #expect(context.preferencesStore.selectedWorkspaceID == 1)
        #expect(context.preferencesStore.selectedWorkspaceName == "Workspace")
    }

    @MainActor
    @Test
    func successfulClockifyConnectionTestLoadsCatalogsAndPersistsResolvedWorkspace() async {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel(clockifyToken: "clockify-token")
        await model.testClockifyConnection()

        #expect(model.clockifyTestResult?.isError == false)
        #expect(model.clockifyWorkspaceCatalogs.count == 1)
        #expect(model.clockifyWorkspaceCatalogs.first?.workspace.id == "workspace-1")
        #expect(model.clockifyWorkspaceCatalogs.first?.workspace.name == "Clockify Workspace")
        #expect(model.clockifyWorkspaceCatalogs.first?.projects.first?.id == "clockify-project-1")
        #expect(model.resolvedClockifyWorkspace?.id == "workspace-1")
        #expect(context.preferencesStore.selectedClockifyWorkspaceID == "workspace-1")
        #expect(context.preferencesStore.selectedClockifyWorkspaceName == "Clockify Workspace")
    }

    @MainActor
    @Test
    func successfulHarvestConnectionTestLoadsCatalogsAndPersistsResolvedAccount() async {
        let context = TestContext()
        defer { context.cleanup() }

        let model = context.makeAppModel(harvestToken: "harvest-token")
        await model.testHarvestConnection()

        #expect(model.harvestTestResult?.isError == false)
        #expect(model.harvestAccountCatalogs.count == 2)
        #expect(model.harvestAccountCatalogs.first?.account.id == 7)
        #expect(model.harvestAccountCatalogs.first?.projects.first?.id == 12)
        #expect(model.harvestAccountCatalogs.first?.projects.first?.taskAssignments.first?.id == 18)
        #expect(model.resolvedHarvestAccount?.id == 7)
        #expect(context.preferencesStore.selectedHarvestAccountID == 7)
        #expect(context.preferencesStore.selectedHarvestAccountName == "Harvest Account")
        // With multiple accounts, project and task are not auto-selected until the user picks an account.
        #expect(context.preferencesStore.selectedHarvestProjectID == nil)
        #expect(context.preferencesStore.selectedHarvestTaskID == nil)
    }

    // MARK: - Partial Submission Failures

    @MainActor
    @Test
    func partialSubmissionFailurePreservesLocalStorageAndReportsFailingProvider() async throws {
        let context = TestContext()
        defer { context.cleanup() }

        let togglService = TogglServiceStub(
            createError: PlannerServiceError.emptyResponse("Toggl rejected the request.")
        )
        let model = context.makeAppModel(
            togglToken: "toggl-token",
            clockifyToken: "clockify-token",
            harvestToken: "harvest-token",
            togglService: togglService
        )
        model.updateRawText("Client implementation")

        await model.processNote()

        let entryID = try #require(model.draft.candidateEntries.first?.id)
        model.setHarvestAssignment(id: entryID, accountID: 7, projectID: 12, taskID: 18)

        await model.submitEntries()

        let snapshot = try context.persistenceController.repository.loadSnapshot(currentDay: context.day)
        #expect(snapshot.storedEntries.count == 1)
        #expect(model.storedEntries.count == 1)

        #expect(model.reviewErrorMessage?.contains("Toggl") == true)
        #expect(model.reviewErrorMessage?.contains("Toggl rejected the request.") == true)

        #expect(model.reviewStatusMessage?.contains("Clockify") == true)
        #expect(model.reviewStatusMessage?.contains("Harvest") == true)
        #expect(model.reviewStatusMessage?.contains("\(AppConfiguration.displayName) Storage") == true)
        #expect(model.reviewStatusMessage?.contains("Toggl") == false)

        #expect(model.draft.candidateEntries.isEmpty == false)
        // Submit's success branch writes a "Saved N entries to … Storage." capture message; the failure
        // branch must not. Anything else (for example the processNote success message) is fine.
        #expect(model.captureStatusMessage?.hasPrefix("Saved ") == false)
    }

    @MainActor
    @Test
    func allExternalSubmissionsFailingStillPreservesLocalStorage() async throws {
        let context = TestContext()
        defer { context.cleanup() }

        let togglService = TogglServiceStub(
            createError: PlannerServiceError.emptyResponse("Toggl rejected the request.")
        )
        let clockifyService = ClockifyServiceStub(
            createError: PlannerServiceError.emptyResponse("Clockify rejected the request.")
        )
        let harvestService = HarvestServiceStub(
            createError: PlannerServiceError.emptyResponse("Harvest rejected the request.")
        )
        let model = context.makeAppModel(
            togglToken: "toggl-token",
            clockifyToken: "clockify-token",
            harvestToken: "harvest-token",
            togglService: togglService,
            clockifyService: clockifyService,
            harvestService: harvestService
        )
        model.updateRawText("Client implementation")

        await model.processNote()

        let entryID = try #require(model.draft.candidateEntries.first?.id)
        model.setHarvestAssignment(id: entryID, accountID: 7, projectID: 12, taskID: 18)

        await model.submitEntries()

        let snapshot = try context.persistenceController.repository.loadSnapshot(currentDay: context.day)
        #expect(snapshot.storedEntries.count == 1)
        #expect(model.storedEntries.count == 1)

        let errorMessage = try #require(model.reviewErrorMessage)
        #expect(errorMessage.contains("Toggl"))
        #expect(errorMessage.contains("Clockify"))
        #expect(errorMessage.contains("Harvest"))

        // Even when every external push failed, the status line still records that app storage succeeded.
        #expect(model.reviewStatusMessage?.contains("\(AppConfiguration.displayName) Storage") == true)
        #expect(model.draft.candidateEntries.isEmpty == false)
        #expect(model.captureStatusMessage?.hasPrefix("Saved ") == false)
    }

    // MARK: - Secrets Storage

    @MainActor
    @Test
    func secretsAreStoredInKeychainAndNotInUserDefaults() async {
        let context = TestContext()
        defer { context.cleanup() }

        // Build the model with no seeded secrets so we can observe each setter in isolation.
        let model = context.makeAppModel(geminiAPIKey: nil)

        let secretCases: [(key: KeychainKey, apply: (String) -> Void)] = [
            (.geminiAPIKey, { model.updateAPIKey($0, for: .gemini) }),
            (.claudeAPIKey, { model.updateAPIKey($0, for: .claude) }),
            (.openAIAPIKey, { model.updateAPIKey($0, for: .openAI) }),
            (.togglAPIToken, { model.updateTogglAPIToken($0) }),
            (.clockifyAPIToken, { model.updateClockifyAPIToken($0) }),
            (.harvestAccessToken, { model.updateHarvestAccessToken($0) })
        ]

        for (key, apply) in secretCases {
            let secret = "SECRET-\(key.rawValue)-\(UUID().uuidString)"
            apply(secret)

            #expect(context.keychainStore.string(for: key) == secret)

            let defaultsSnapshot = context.userDefaults.dictionaryRepresentation()
            for (defaultsKey, defaultsValue) in defaultsSnapshot {
                if let stringValue = defaultsValue as? String {
                    #expect(
                        stringValue != secret,
                        "Secret for \(key.rawValue) leaked into UserDefaults at key '\(defaultsKey)'."
                    )
                }
                #expect(
                    defaultsKey != key.rawValue,
                    "UserDefaults must not carry a key named \(key.rawValue); that namespace is reserved for Keychain."
                )
            }
        }
    }
}

@MainActor
private struct TestContext {
    let applicationName = "PlannerTests.\(UUID().uuidString)"
    let day = TestSupport.selectedDay()
    let preferencesStore: PreferencesStore
    let persistenceController: PlannerPersistenceController
    let keychainStore: KeychainStoreStub

    init(provider: LLMProvider = .gemini, appleIntelligenceEnabled: Bool = true) {
        let defaults = UserDefaults(suiteName: applicationName)!
        defaults.removePersistentDomain(forName: applicationName)

        let preferencesStore = PreferencesStore(userDefaults: defaults)
        preferencesStore.selectedLLMProvider = provider
        preferencesStore.isAppleIntelligenceEnabled = appleIntelligenceEnabled
        self.preferencesStore = preferencesStore
        self.persistenceController = try! PlannerPersistenceController.inMemory()
        self.keychainStore = KeychainStoreStub()
    }

    var userDefaults: UserDefaults {
        UserDefaults(suiteName: applicationName)!
    }

    func makeAppModel(
        togglToken: String = "",
        clockifyToken: String = "",
        harvestToken: String = "",
        geminiAPIKey: String? = "demo-key",
        claudeAPIKey: String? = nil,
        openAIAPIKey: String? = nil,
        appleService: LLMServiceStub = LLMServiceStub(response: LLMServiceStub.defaultResponse),
        geminiService: LLMServiceStub = LLMServiceStub(response: LLMServiceStub.defaultResponse),
        claudeService: LLMServiceStub = LLMServiceStub(response: LLMServiceStub.defaultResponse),
        openAIService: LLMServiceStub = LLMServiceStub(response: LLMServiceStub.defaultResponse),
        togglService: TogglServiceStub = TogglServiceStub(),
        clockifyService: ClockifyServiceStub = ClockifyServiceStub(),
        harvestService: HarvestServiceStub = HarvestServiceStub()
    ) -> PlannerAppModel {
        if let geminiAPIKey {
            keychainStore.set(geminiAPIKey, for: .geminiAPIKey)
        }
        if let claudeAPIKey {
            keychainStore.set(claudeAPIKey, for: .claudeAPIKey)
        }
        if let openAIAPIKey {
            keychainStore.set(openAIAPIKey, for: .openAIAPIKey)
        }
        if !togglToken.isEmpty {
            keychainStore.set(togglToken, for: .togglAPIToken)
        }
        if !clockifyToken.isEmpty {
            keychainStore.set(clockifyToken, for: .clockifyAPIToken)
        }
        if !harvestToken.isEmpty {
            keychainStore.set(harvestToken, for: .harvestAccessToken)
        }

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

private func expectedExportFilename(
    format: AppStorageExportFormat,
    day: Date
) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TestSupport.timeZone
    let components = calendar.dateComponents([.year, .month, .day], from: day)
    let localDay = String(
        format: "%04d-%02d-%02d",
        components.year ?? 0,
        components.month ?? 0,
        components.day ?? 0
    )
    return "\(AppConfiguration.exportFilenamePrefix)-\(format.rawValue)-\(localDay)-\(localDay).json"
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
    var createError: Error?

    func fetchCurrentUser(apiToken: String) async throws -> TogglCurrentUserDTO {
        TogglCurrentUserDTO(id: 1, fullname: "Test User", email: "user@example.com")
    }

    func fetchWorkspaces(apiToken: String) async throws -> [WorkspaceSummary] {
        [WorkspaceSummary(id: 1, name: "Workspace")]
    }

    func fetchProjects(apiToken: String, workspaceID: Int) async throws -> [ProjectSummary] {
        [ProjectSummary(id: 101, name: "Client Work", workspaceId: workspaceID)]
    }

    func createTimeEntries(
        _ submissions: [StoredTimeEntryRecord.TogglSubmission],
        apiToken: String
    ) async throws -> [TogglCreatedTimeEntryDTO] {
        if let createError { throw createError }
        return submissions.enumerated().map { index, submission in
            TogglCreatedTimeEntryDTO(id: index + 1, description: submission.request.description)
        }
    }
}

private struct ClockifyServiceStub: ClockifyServicing {
    var createError: Error?

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
        if let createError { throw createError }
        return submissions.enumerated().map { index, submission in
            ClockifyCreatedTimeEntryDTO(id: "clockify-\(index)", description: submission.request.description)
        }
    }
}

private struct HarvestServiceStub: HarvestServicing {
    var createError: Error?

    func fetchAccounts(accessToken: String) async throws -> [HarvestAccountSummary] {
        [
            HarvestAccountSummary(id: 7, name: "Harvest Account"),
            HarvestAccountSummary(id: 8, name: "Internal Account")
        ]
    }

    func fetchCurrentUser(accessToken: String, accountID: Int) async throws -> HarvestCurrentUserDTO {
        HarvestCurrentUserDTO(id: 1, firstName: "Harvest", lastName: "User", email: "harvest@example.com")
    }

    func fetchProjectAssignments(accessToken: String, accountID: Int) async throws -> [HarvestProjectSummary] {
        switch accountID {
        case 7:
            return [
                HarvestProjectSummary(
                    id: 12,
                    name: "Client Work",
                    taskAssignments: [HarvestTaskSummary(id: 18, name: "Implementation")]
                )
            ]
        default:
            return [
                HarvestProjectSummary(
                    id: 22,
                    name: "Internal Ops",
                    taskAssignments: [HarvestTaskSummary(id: 28, name: "Admin")]
                )
            ]
        }
    }

    func createTimeEntries(
        _ submissions: [StoredTimeEntryRecord.HarvestSubmission],
        accessToken: String
    ) async throws -> [HarvestCreatedTimeEntryDTO] {
        if let createError { throw createError }
        return submissions.enumerated().map { index, submission in
            HarvestCreatedTimeEntryDTO(id: index + 1, notes: submission.timestampRequest.notes)
        }
    }
}
