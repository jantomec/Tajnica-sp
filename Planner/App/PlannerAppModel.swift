import Foundation
import SwiftUI
import Combine

@MainActor
final class PlannerAppModel: ObservableObject {
    enum Tab: Hashable {
        case capture
        case review
        case diary
        case settings
    }

    enum SettingsTab: Hashable {
        case aiProvider
        case timeTracker
        case aboutMe
    }

    /// Small feedback value shown inline next to a button.
    struct InlineResult: Equatable {
        let message: String
        let isError: Bool
    }

    enum AppleIntelligenceAvailability: Equatable {
        case unknown
        case available
        case unavailable
    }

    private struct LLMRequestConfiguration {
        let provider: LLMProvider
        let apiKey: String
        let model: String
    }

    struct ExportPreparation {
        let document: AppStorageExportDocument
        let filename: String
    }

    // MARK: - Navigation

    @Published var selectedTab: Tab = .capture
    @Published var selectedSettingsTab: SettingsTab = .aiProvider
    @Published private(set) var pendingReviewEntryID: CandidateTimeEntry.ID?

    // MARK: - Draft

    @Published private(set) var draft: PlannerDraft
    @Published private(set) var diaryPromptHistory: [DiaryPromptRecord] = []
    @Published private(set) var storedEntries: [StoredTimeEntryRecord] = []

    // MARK: - Toggl data

    @Published private(set) var availableWorkspaces: [WorkspaceSummary] = []
    @Published private(set) var availableProjects: [ProjectSummary] = []
    @Published private(set) var resolvedWorkspace: WorkspaceSummary?
    @Published private(set) var togglWorkspaceCatalogs: [TogglWorkspaceCatalog] = []

    // MARK: - Clockify data

    @Published private(set) var availableClockifyWorkspaces: [ClockifyWorkspaceSummary] = []
    @Published private(set) var resolvedClockifyWorkspace: ClockifyWorkspaceSummary?
    @Published private(set) var clockifyWorkspaceCatalogs: [ClockifyWorkspaceCatalog] = []

    // MARK: - Harvest data

    @Published private(set) var availableHarvestAccounts: [HarvestAccountSummary] = []
    @Published private(set) var resolvedHarvestAccount: HarvestAccountSummary?
    @Published private(set) var availableHarvestProjects: [HarvestProjectSummary] = []
    @Published private(set) var resolvedHarvestProject: HarvestProjectSummary?
    @Published private(set) var resolvedHarvestTask: HarvestTaskSummary?
    @Published private(set) var harvestAccountCatalogs: [HarvestAccountCatalog] = []

    // MARK: - LLM provider

    @Published var selectedProvider: LLMProvider {
        didSet { preferencesStore.selectedLLMProvider = selectedProvider }
    }
    @Published var isAppleIntelligenceEnabled: Bool {
        didSet { preferencesStore.isAppleIntelligenceEnabled = isAppleIntelligenceEnabled }
    }
    @Published private(set) var appleIntelligenceAvailability: AppleIntelligenceAvailability = .unknown
    @Published var appleIntelligenceResult: InlineResult?
    @Published var llmModel: String {
        didSet {
            preferencesStore.setLLMModel(llmModel.trimmed.nilIfBlank, for: selectedProvider)
        }
    }

    // MARK: - API keys (per-provider)

    @Published var geminiAPIKey: String
    @Published var claudeAPIKey: String
    @Published var openAIAPIKey: String
    @Published var togglAPIToken: String
    @Published var clockifyAPIToken: String
    @Published var harvestAccessToken: String

    // MARK: - User context (About Me)

    @Published var userContext: String {
        didSet { preferencesStore.userContext = userContext }
    }

    // MARK: - Status messages

    @Published var captureStatusMessage: String?
    @Published var captureErrorMessage: String?
    @Published var reviewStatusMessage: String?
    @Published var reviewErrorMessage: String?

    /// Inline feedback for the LLM connection test button.
    @Published var llmTestResult: InlineResult?
    /// Inline feedback for the Toggl connection test button.
    @Published var togglTestResult: InlineResult?
    /// Inline feedback for the Clockify connection test button.
    @Published var clockifyTestResult: InlineResult?
    /// Inline feedback for the Harvest connection test button.
    @Published var harvestTestResult: InlineResult?
    /// Inline feedback for the polish user context button.
    @Published var polishResult: InlineResult?

    // MARK: - Loading states

    @Published var isProcessing = false
    @Published var isSubmitting = false
    @Published var isRefreshingWorkspaces = false
    @Published var isTestingLLM = false
    @Published var isTestingToggl = false
    @Published var isRefreshingClockifyWorkspaces = false
    @Published var isTestingClockify = false
    @Published var isRefreshingHarvestAssignments = false
    @Published var isTestingHarvest = false
    @Published var isPolishingContext = false
    @Published var shouldConfirmRegeneration = false

    // MARK: - Dependencies

    private let preferencesStore: PreferencesStore
    private let syncRepository: PlannerSyncRepository
    private let storageSyncMode: PlannerPersistenceController.SyncMode
    private let keychainStore: KeychainStoring
    private let llmRouter: LLMServiceRouter
    private let togglService: TogglServicing
    private let clockifyService: ClockifyServicing
    private let harvestService: HarvestServicing
    private let validator: TimeEntryValidating
    private let timeZone: TimeZone
    private var didStart = false
    private var pendingDraftPersistenceTask: Task<Void, Never>?
    private var hasPendingDraftPersistence = false

    init(
        preferencesStore: PreferencesStore,
        syncRepository: PlannerSyncRepository,
        storageSyncMode: PlannerPersistenceController.SyncMode,
        keychainStore: KeychainStoring,
        llmRouter: LLMServiceRouter,
        togglService: TogglServicing,
        clockifyService: ClockifyServicing,
        harvestService: HarvestServicing,
        validator: TimeEntryValidating? = nil,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        self.preferencesStore = preferencesStore
        self.syncRepository = syncRepository
        self.storageSyncMode = storageSyncMode
        self.keychainStore = keychainStore
        self.llmRouter = llmRouter
        self.togglService = togglService
        self.clockifyService = clockifyService
        self.harvestService = harvestService
        self.validator = validator ?? TimeEntryValidator()
        self.timeZone = timeZone

        self.draft = PlannerDraft.empty(on: Self.normalizedDay(Date.now, in: timeZone))
        self.geminiAPIKey = keychainStore.string(for: .geminiAPIKey) ?? ""
        self.claudeAPIKey = keychainStore.string(for: .claudeAPIKey) ?? ""
        self.openAIAPIKey = keychainStore.string(for: .openAIAPIKey) ?? ""
        self.togglAPIToken = keychainStore.string(for: .togglAPIToken) ?? ""
        self.clockifyAPIToken = keychainStore.string(for: .clockifyAPIToken) ?? ""
        self.harvestAccessToken = keychainStore.string(for: .harvestAccessToken) ?? ""
        let initialProvider = preferencesStore.selectedLLMProvider
        self.selectedProvider = initialProvider
        self.isAppleIntelligenceEnabled = preferencesStore.isAppleIntelligenceEnabled
        self.llmModel = preferencesStore.llmModel(for: initialProvider) ?? initialProvider.defaultModel
        self.userContext = preferencesStore.userContext

        loadPersistedContent()
        synchronizeNoteDateWithToday()
    }

    deinit {
        pendingDraftPersistenceTask?.cancel()
    }

    static func live(
        syncRepository: PlannerSyncRepository,
        storageSyncMode: PlannerPersistenceController.SyncMode
    ) -> PlannerAppModel {
        let httpClient = URLSessionHTTPClient()
        let appleFoundationService = AppleFoundationModelsService()
        let geminiService = GeminiService(httpClient: httpClient)
        let claudeService = ClaudeService(httpClient: httpClient)
        let openAIService = OpenAIService(httpClient: httpClient)

        return PlannerAppModel(
            preferencesStore: PreferencesStore(),
            syncRepository: syncRepository,
            storageSyncMode: storageSyncMode,
            keychainStore: KeychainStore(),
            llmRouter: LLMServiceRouter(
                appleFoundationService: appleFoundationService,
                geminiService: geminiService,
                claudeService: claudeService,
                openAIService: openAIService
            ),
            togglService: TogglService(httpClient: httpClient),
            clockifyService: ClockifyService(httpClient: httpClient),
            harvestService: HarvestService(httpClient: httpClient)
        )
    }

    // MARK: - Computed properties

    /// The API key for the currently selected LLM provider.
    var activeAPIKey: String {
        switch selectedProvider {
        case .appleFoundation: ""
        case .disabled: ""
        case .gemini: geminiAPIKey
        case .claude: claudeAPIKey
        case .openAI: openAIAPIKey
        }
    }

    /// The effective model, falling back to the provider's default.
    var effectiveModel: String {
        llmModel.trimmed.nilIfBlank ?? selectedProvider.defaultModel
    }

    var isAppleIntelligenceAvailable: Bool {
        appleIntelligenceAvailability == .available
    }

    var isSelectedProviderConfigured: Bool {
        selectedProvider.isExternalProvider && !activeAPIKey.trimmed.isEmpty
    }

    var isAIConfigured: Bool {
        if isSelectedProviderConfigured {
            return true
        }

        guard isAppleIntelligenceEnabled else { return false }
        return appleIntelligenceAvailability != .unavailable
    }

    var canTestLLMProvider: Bool {
        isSelectedProviderConfigured && !isTestingLLM
    }

    var canPolishUserContext: Bool {
        !userContext.isBlank && isAIConfigured && !isPolishingContext
    }

    var canProcess: Bool {
        !draft.note.rawText.isBlank && isAIConfigured && !isProcessing
    }

    var canSubmit: Bool {
        !draft.candidateEntries.isEmpty && !isSubmitting
    }

    var totalErrorCount: Int {
        draft.candidateEntries.reduce(into: 0) { partialResult, entry in
            partialResult += entry.validationIssues.filter { $0.severity == .error }.count
        }
    }

    var totalWarningCount: Int {
        draft.candidateEntries.reduce(into: 0) { partialResult, entry in
            partialResult += entry.validationIssues.filter { $0.severity == .warning }.count
        }
    }

    var diaryFeedItems: [DiaryFeedItem] {
        DiaryFeedItem.makeFeedItems(from: diaryPromptHistory)
    }

    var isUsingICloudStorage: Bool {
        storageSyncMode == .cloudKit
    }

    var appStorageDisplayName: String {
        "\(AppConfiguration.displayName) Storage"
    }

    var appStorageStatusMessage: String {
        if isUsingICloudStorage {
            return "\(AppConfiguration.displayName) can use iCloud-backed app storage on this device, so saved entries sync through your private iCloud data."
        }

        return "\(AppConfiguration.displayName) is currently using local app storage. If you want sync, enable iCloud for this app in System Settings."
    }

    var configuredExternalTimeTrackers: [TimeTrackerProvider] {
        TimeTrackerProvider.allCases.filter(hasStoredCredential(for:))
    }

    var enabledTimeTrackers: Set<TimeTrackerProvider> {
        Set(configuredExternalTimeTrackers)
    }

    var availableHarvestTasks: [HarvestTaskSummary] {
        resolvedHarvestProject?.taskAssignments ?? []
    }

    var totalTogglProjectCount: Int {
        togglWorkspaceCatalogs.reduce(into: 0) { $0 += $1.projects.count }
    }

    var totalClockifyProjectCount: Int {
        clockifyWorkspaceCatalogs.reduce(into: 0) { $0 += $1.projects.count }
    }

    var totalHarvestProjectCount: Int {
        harvestAccountCatalogs.reduce(into: 0) { $0 += $1.projects.count }
    }

    var totalHarvestTaskCount: Int {
        harvestAccountCatalogs.reduce(into: 0) { partialResult, account in
            partialResult += account.projects.reduce(into: 0) { $0 += $1.taskAssignments.count }
        }
    }

    var configuredSubmissionDestinationNames: [String] {
        [appStorageDisplayName] + configuredExternalTimeTrackers.map(\.displayName)
    }

    var submissionDestinationSummary: String {
        let external = configuredExternalTimeTrackers.map(\.displayName)
        if external.isEmpty {
            return "Submitted entries are always saved in \(appStorageDisplayName). No external tracker is currently connected."
        }

        return "Submitted entries are saved in \(appStorageDisplayName) and also sent to \(Self.commaSeparatedList(external))."
    }

    var defaultExportStartDate: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(byAdding: .day, value: -30, to: currentDay) ?? currentDay
    }

    var defaultExportEndDate: Date {
        currentDay
    }

    var defaultExportFormat: AppStorageExportFormat {
        .toggl
    }

    // MARK: - Lifecycle

    func start() async {
        guard !didStart else { return }
        didStart = true
        synchronizeNoteDateWithToday()

        _ = await refreshTrackerReferenceData(showErrors: false)
    }

    func refreshTimeTrackerConnectionsOnViewLoad() async {
        if !togglAPIToken.trimmed.isEmpty {
            await testTogglConnection()
        }

        if !clockifyAPIToken.trimmed.isEmpty {
            await testClockifyConnection()
        }

        if !harvestAccessToken.trimmed.isEmpty {
            await testHarvestConnection()
        }
    }

    func handleScenePhaseChange(_ scenePhase: ScenePhase) async {
        switch scenePhase {
        case .active:
            guard !hasPendingDraftPersistence else { return }
            loadPersistedContent()
        case .inactive, .background:
            flushPendingDraftPersistence()
        @unknown default:
            break
        }
    }

    func refreshNoteDateForPresentation() {
        synchronizeNoteDateWithToday()
    }

    func handleIncomingURL(_ url: URL) {
        guard let deepLink = PlannerDeepLink(url: url) else { return }

        switch deepLink {
        case .capture:
            navigateToCapture()
        case let .review(entryID):
            navigateToReview(entryID: entryID)
        }
    }

    func consumePendingReviewEntryIfAvailable() -> CandidateTimeEntry? {
        guard let pendingReviewEntryID,
              let entry = draft.candidateEntries.first(where: { $0.id == pendingReviewEntryID }) else {
            return nil
        }

        self.pendingReviewEntryID = nil
        return entry
    }

    // MARK: - Note editing

    func updateRawText(_ rawText: String) {
        synchronizeNoteDateWithToday()
        draft.note.rawText = rawText
        draft.note.updatedAt = .now
        persistDraft(immediately: false)
    }

    func appendToDraft(_ additionalText: String) {
        let trimmed = additionalText.trimmed
        guard !trimmed.isEmpty else { return }

        synchronizeNoteDateWithToday()
        let existing = draft.note.rawText.trimmed
        draft.note.rawText = existing.isEmpty ? trimmed : "\(existing)\n\(trimmed)"
        draft.note.updatedAt = .now
        captureStatusMessage = nil
        captureErrorMessage = nil
        persistDraft()
    }

    func addDraftEntry(
        description: String,
        start: Date,
        stop: Date,
        billable: Bool? = nil
    ) {
        synchronizeNoteDateWithToday()
        let alignedStart = LocalTimeParser.shift(start, to: draft.note.date, in: timeZone)
        let alignedStop = LocalTimeParser.shift(stop, to: draft.note.date, in: timeZone)

        let entry = CandidateTimeEntry(
            date: draft.note.date,
            start: alignedStart,
            stop: alignedStop,
            description: description,
            billable: billable,
            source: .user
        )

        draft.candidateEntries.append(entry)
        captureStatusMessage = nil
        captureErrorMessage = nil
        reviewStatusMessage = nil
        reviewErrorMessage = nil
        validateAndPersistEntries()
    }

    // MARK: - API key management

    func updateAPIKey(_ value: String, for provider: LLMProvider) {
        switch provider {
        case .appleFoundation:
            return
        case .disabled:
            return
        case .gemini:
            geminiAPIKey = value
            saveSecret(value, for: .geminiAPIKey)
        case .claude:
            claudeAPIKey = value
            saveSecret(value, for: .claudeAPIKey)
        case .openAI:
            openAIAPIKey = value
            saveSecret(value, for: .openAIAPIKey)
        }
    }

    func updateTogglAPIToken(_ value: String) {
        let previous = togglAPIToken.trimmed
        togglAPIToken = value
        saveSecret(value, for: .togglAPIToken)

        if value.trimmed != previous {
            clearTogglCatalogs()
            togglTestResult = nil
            preferencesStore.storeResolvedWorkspace(nil)
        }
    }

    func updateClockifyAPIToken(_ value: String) {
        let previous = clockifyAPIToken.trimmed
        clockifyAPIToken = value
        saveSecret(value, for: .clockifyAPIToken)

        if value.trimmed != previous {
            clearClockifyCatalogs()
            clockifyTestResult = nil
            preferencesStore.storeResolvedClockifyWorkspace(nil)
        }
    }

    func updateHarvestAccessToken(_ value: String) {
        let previous = harvestAccessToken.trimmed
        harvestAccessToken = value
        saveSecret(value, for: .harvestAccessToken)

        if value.trimmed != previous {
            clearHarvestCatalogs()
            harvestTestResult = nil
            preferencesStore.storeResolvedHarvestAccount(nil)
            preferencesStore.storeResolvedHarvestProject(nil)
            preferencesStore.storeResolvedHarvestTask(nil)
        }
    }

    func storeTimeTrackerCredential(_ value: String, for provider: TimeTrackerProvider) async {
        switch provider {
        case .toggl:
            updateTogglAPIToken(value)
            await testTogglConnection()
        case .clockify:
            updateClockifyAPIToken(value)
            await testClockifyConnection()
        case .harvest:
            updateHarvestAccessToken(value)
            await testHarvestConnection()
        }
    }

    func disconnectTimeTracker(_ provider: TimeTrackerProvider) {
        switch provider {
        case .toggl:
            updateTogglAPIToken("")
        case .clockify:
            updateClockifyAPIToken("")
        case .harvest:
            updateHarvestAccessToken("")
        }
    }

    func updateSelectedProvider(_ provider: LLMProvider) {
        guard provider.isSelectableExternalProvider else { return }
        guard selectedProvider != provider else { return }

        // Defer changes so we don't publish during a view update cycle.
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.selectedProvider = provider

            // After the provider change, load this provider's stored model (or default).
            guard self.selectedProvider == provider else { return }
            self.llmModel = self.preferencesStore.llmModel(for: provider) ?? provider.defaultModel
        }
    }

    func updateLLMModel(_ value: String) {
        // Defer the change to avoid publishing within a view update cycle.
        // Preserve the user's input verbatim; effectiveModel falls back to default when blank.
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.llmModel = value
        }
    }

    func hasStoredCredential(for provider: TimeTrackerProvider) -> Bool {
        switch provider {
        case .toggl:
            !togglAPIToken.trimmed.isEmpty
        case .clockify:
            !clockifyAPIToken.trimmed.isEmpty
        case .harvest:
            !harvestAccessToken.trimmed.isEmpty
        }
    }

    func testResult(for provider: TimeTrackerProvider) -> InlineResult? {
        switch provider {
        case .toggl:
            togglTestResult
        case .clockify:
            clockifyTestResult
        case .harvest:
            harvestTestResult
        }
    }

    func isTestingTimeTracker(_ provider: TimeTrackerProvider) -> Bool {
        switch provider {
        case .toggl:
            isTestingToggl || isRefreshingWorkspaces
        case .clockify:
            isTestingClockify || isRefreshingClockifyWorkspaces
        case .harvest:
            isTestingHarvest || isRefreshingHarvestAssignments
        }
    }

    func testingMessage(for provider: TimeTrackerProvider) -> String {
        switch provider {
        case .toggl:
            return "Checking the Toggl token and loading workspaces and projects."
        case .clockify:
            return "Checking the Clockify API key and loading workspaces and projects."
        case .harvest:
            return "Checking the Harvest token and loading accounts, projects, and tasks."
        }
    }

    @discardableResult
    func refreshAppleIntelligenceAvailability() -> Bool {
        appleIntelligenceResult = nil

        do {
            try llmRouter.checkAppleIntelligenceAvailability()
            appleIntelligenceAvailability = .available
            return true
        } catch {
            appleIntelligenceAvailability = .unavailable
            appleIntelligenceResult = InlineResult(message: error.localizedDescription, isError: true)
            return false
        }
    }

    // MARK: - Draft management

    func clearDraft() {
        synchronizeNoteDateWithToday()
        draft = PlannerDraft.empty(on: currentDay)
        pendingReviewEntryID = nil
        captureStatusMessage = nil
        captureErrorMessage = nil
        reviewStatusMessage = nil
        reviewErrorMessage = nil
        clearPersistedDraft()
    }

    // MARK: - Note processing

    func processNote(replacingExistingEntries: Bool = false) async {
        captureErrorMessage = nil
        captureStatusMessage = nil
        synchronizeNoteDateWithToday()

        guard isAIConfigured else {
            captureErrorMessage = aiConfigurationErrorMessage
            return
        }

        if !replacingExistingEntries, !draft.candidateEntries.isEmpty {
            shouldConfirmRegeneration = true
            return
        }

        archiveCurrentPromptIfNeeded()

        isProcessing = true
        defer { isProcessing = false }

        let extractionContext = await refreshTrackerReferenceData(showErrors: false)

        do {
            let outcome = try await performPreferredLLMOperation { service, configuration in
                try await service.extractTimeEntries(
                    apiKey: configuration.apiKey,
                    model: configuration.model,
                    note: draft.note,
                    timeZone: timeZone,
                    extractionContext: extractionContext
                )
            }

            let entries = try GeminiEntryConverter.convert(
                response: outcome.value,
                selectedDate: draft.note.date,
                timeZone: timeZone
            )

            draft.summary = outcome.value.summary?.trimmed.nilIfBlank
            draft.assumptions = outcome.value.assumptions.map(\.trimmed).filter { !$0.isEmpty }
            draft.lastProcessedAt = .now
            draft.candidateEntries = validate(entries: entries, context: extractionContext)
            persistDraft()

            captureErrorMessage = nil
            captureStatusMessage = processSuccessMessage(
                entryCount: draft.candidateEntries.count,
                provider: outcome.provider,
                usedAppleFallback: outcome.usedAppleFallback
            )
            navigateToReview(entryID: nil)
        } catch {
            captureErrorMessage = error.localizedDescription
        }
    }

    // MARK: - Entry management

    func addEntry() {
        synchronizeNoteDateWithToday()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let start: Date
        let stop: Date

        if let last = draft.candidateEntries.last {
            start = last.stop
            stop = calendar.date(byAdding: .hour, value: 1, to: start) ?? start
        } else {
            start = (try? LocalTimeParser.parse("09:00", on: draft.note.date, in: timeZone)) ?? draft.note.date
            stop = (try? LocalTimeParser.parse("10:00", on: draft.note.date, in: timeZone)) ?? start
        }

        let entry = CandidateTimeEntry(
            date: draft.note.date,
            start: start,
            stop: stop,
            description: "",
            source: .user
        )

        draft.candidateEntries.append(entry)
        validateAndPersistEntries()
    }

    func duplicateEntry(id: CandidateTimeEntry.ID) {
        synchronizeNoteDateWithToday()
        guard let existing = draft.candidateEntries.first(where: { $0.id == id }) else { return }

        var duplicate = existing
        duplicate.id = UUID()
        duplicate.source = .user
        draft.candidateEntries.append(duplicate)
        validateAndPersistEntries()
    }

    func deleteEntry(id: CandidateTimeEntry.ID) {
        synchronizeNoteDateWithToday()
        draft.candidateEntries.removeAll { $0.id == id }
        if pendingReviewEntryID == id {
            pendingReviewEntryID = nil
        }
        validateAndPersistEntries()
    }

    func saveEditedEntry(_ entry: CandidateTimeEntry) {
        synchronizeNoteDateWithToday()
        guard let index = draft.candidateEntries.firstIndex(where: { $0.id == entry.id }) else { return }
        var updated = entry
        updated.source = .user
        draft.candidateEntries[index] = updated
        validateAndPersistEntries()
    }

    func setEntryBillable(id: CandidateTimeEntry.ID, billable: Bool?) {
        synchronizeNoteDateWithToday()
        updateDraftEntry(id: id) { entry in
            entry.billable = billable
        }
    }

    func setEntryTags(id: CandidateTimeEntry.ID, tags: [String]) {
        synchronizeNoteDateWithToday()
        updateDraftEntry(id: id) { entry in
            entry.tags = tags.trimmedDeduplicated()
        }
    }

    func setTogglAssignment(
        id: CandidateTimeEntry.ID,
        workspaceID: Int?,
        projectID: Int?
    ) {
        synchronizeNoteDateWithToday()
        updateDraftEntry(id: id) { entry in
            entry.togglTarget = buildTogglTarget(workspaceID: workspaceID, projectID: projectID)
        }
    }

    func setClockifyAssignment(
        id: CandidateTimeEntry.ID,
        workspaceID: String?,
        projectID: String?
    ) {
        synchronizeNoteDateWithToday()
        updateDraftEntry(id: id) { entry in
            entry.clockifyTarget = buildClockifyTarget(workspaceID: workspaceID, projectID: projectID)
        }
    }

    func setHarvestAssignment(
        id: CandidateTimeEntry.ID,
        accountID: Int?,
        projectID: Int?,
        taskID: Int?
    ) {
        synchronizeNoteDateWithToday()
        updateDraftEntry(id: id) { entry in
            entry.harvestTarget = buildHarvestTarget(accountID: accountID, projectID: projectID, taskID: taskID)
        }
    }

    func clearTrackerAssignment(
        id: CandidateTimeEntry.ID,
        provider: TimeTrackerProvider
    ) {
        synchronizeNoteDateWithToday()
        updateDraftEntry(id: id) { entry in
            switch provider {
            case .toggl:
                entry.togglTarget = nil
            case .clockify:
                entry.clockifyTarget = nil
            case .harvest:
                entry.harvestTarget = nil
            }
        }
    }

    func ensureTrackerCatalogsLoaded(for provider: TimeTrackerProvider) async throws {
        switch provider {
        case .toggl:
            _ = try await loadTogglCatalogs()
        case .clockify:
            _ = try await loadClockifyCatalogs()
        case .harvest:
            _ = try await loadHarvestCatalogs()
        }
    }

    // MARK: - Connection testing

    func testLLMConnection() async {
        llmTestResult = nil

        guard selectedProvider.isExternalProvider else {
            llmTestResult = InlineResult(
                message: "Select Gemini, Claude, or OpenAI to test a cloud AI provider.",
                isError: true
            )
            return
        }

        guard isSelectedProviderConfigured else {
            llmTestResult = InlineResult(message: "Enter a \(selectedProvider.displayName) API key first.", isError: true)
            return
        }

        isTestingLLM = true
        defer { isTestingLLM = false }

        do {
            let service = llmRouter.service(for: selectedProvider)
            let status = try await service.testConnection(
                apiKey: activeAPIKey.trimmed,
                model: effectiveModel
            )
            llmTestResult = InlineResult(message: selectedProvider.connectionSuccessMessage(status: status), isError: false)
        } catch {
            llmTestResult = InlineResult(message: error.localizedDescription, isError: true)
        }
    }

    func testTogglConnection() async {
        togglTestResult = nil

        guard !togglAPIToken.trimmed.isEmpty else {
            togglTestResult = InlineResult(message: "Enter a Toggl API token first.", isError: true)
            return
        }

        isTestingToggl = true
        defer { isTestingToggl = false }

        do {
            let user = try await togglService.fetchCurrentUser(apiToken: togglAPIToken.trimmed)
            let catalogs = try await loadTogglCatalogs()
            let name = user.fullname?.trimmed.nilIfBlank ?? user.email?.trimmed.nilIfBlank ?? "User"
            togglTestResult = InlineResult(
                message: "Connected as \(name) — loaded \(catalogs.count) workspace(s) and \(totalTogglProjectCount) project(s).",
                isError: false
            )
        } catch {
            togglTestResult = InlineResult(message: error.localizedDescription, isError: true)
        }
    }

    func testClockifyConnection() async {
        clockifyTestResult = nil

        guard !clockifyAPIToken.trimmed.isEmpty else {
            clockifyTestResult = InlineResult(message: "Enter a Clockify API key first.", isError: true)
            return
        }

        isTestingClockify = true
        defer { isTestingClockify = false }

        do {
            let user = try await clockifyService.fetchCurrentUser(apiKey: clockifyAPIToken.trimmed)
            let name = user.name?.trimmed.nilIfBlank ?? user.email?.trimmed.nilIfBlank ?? "User"
            let catalogs = try await loadClockifyCatalogs()
            clockifyTestResult = InlineResult(
                message: "Connected as \(name) — loaded \(catalogs.count) workspace(s) and \(totalClockifyProjectCount) project(s).",
                isError: false
            )
        } catch {
            clockifyTestResult = InlineResult(message: error.localizedDescription, isError: true)
        }
    }

    func testHarvestConnection() async {
        harvestTestResult = nil

        guard !harvestAccessToken.trimmed.isEmpty else {
            harvestTestResult = InlineResult(message: "Enter a Harvest access token first.", isError: true)
            return
        }

        isTestingHarvest = true
        defer { isTestingHarvest = false }

        do {
            let catalogs = try await loadHarvestCatalogs()
            guard let account = catalogs.first?.account else {
                throw PlannerServiceError.noResolvedHarvestTarget
            }
            let user = try await harvestService.fetchCurrentUser(
                accessToken: harvestAccessToken.trimmed,
                accountID: account.id
            )

            let name = [user.firstName?.trimmed, user.lastName?.trimmed]
                .compactMap { $0?.nilIfBlank }
                .joined(separator: " ")
                .nilIfBlank
                ?? user.email?.trimmed.nilIfBlank
                ?? "User"

            harvestTestResult = InlineResult(
                message: "Connected as \(name) — loaded \(catalogs.count) account(s), \(totalHarvestProjectCount) project(s), and \(totalHarvestTaskCount) task(s).",
                isError: false
            )
        } catch {
            harvestTestResult = InlineResult(message: error.localizedDescription, isError: true)
        }
    }

    // MARK: - Magic wand (polish user context)

    func polishUserContext() async {
        polishResult = nil

        guard isAIConfigured else {
            polishResult = InlineResult(message: aiConfigurationErrorMessage, isError: true)
            return
        }

        guard !userContext.isBlank else {
            polishResult = InlineResult(message: "Write something about yourself first.", isError: true)
            return
        }

        isPolishingContext = true
        defer { isPolishingContext = false }

        do {
            let outcome = try await performPreferredLLMOperation { service, configuration in
                try await service.polishUserContext(
                    apiKey: configuration.apiKey,
                    model: configuration.model,
                    rawText: userContext
                )
            }
            userContext = outcome.value
            polishResult = InlineResult(
                message: outcome.usedAppleFallback
                    ? "Polished successfully with Apple Intelligence fallback."
                    : "Polished successfully.",
                isError: false
            )
        } catch {
            polishResult = InlineResult(message: error.localizedDescription, isError: true)
        }
    }

    // MARK: - Tracker reference data

    private var activeTrackerExtractionContext: LLMExtractionContext {
        LLMExtractionContext(
            userContext: userContext.trimmed.nilIfBlank,
            togglWorkspaces: togglWorkspaceCatalogs,
            clockifyWorkspaces: clockifyWorkspaceCatalogs,
            harvestAccounts: harvestAccountCatalogs
        )
    }

    private func clearTogglCatalogs() {
        availableWorkspaces = []
        availableProjects = []
        resolvedWorkspace = nil
        togglWorkspaceCatalogs = []
    }

    private func clearClockifyCatalogs() {
        availableClockifyWorkspaces = []
        resolvedClockifyWorkspace = nil
        clockifyWorkspaceCatalogs = []
    }

    private func clearHarvestCatalogs() {
        availableHarvestAccounts = []
        resolvedHarvestAccount = nil
        availableHarvestProjects = []
        resolvedHarvestProject = nil
        resolvedHarvestTask = nil
        harvestAccountCatalogs = []
    }

    @discardableResult
    private func loadTogglCatalogs() async throws -> [TogglWorkspaceCatalog] {
        guard !togglAPIToken.trimmed.isEmpty else {
            clearTogglCatalogs()
            return []
        }

        isRefreshingWorkspaces = true
        defer { isRefreshingWorkspaces = false }

        let workspaces = try await togglService.fetchWorkspaces(apiToken: togglAPIToken.trimmed)
        let catalogs = try await loadTogglCatalogs(for: workspaces)

        availableWorkspaces = workspaces
        availableProjects = catalogs.count == 1 ? (catalogs.first?.projects ?? []) : []
        resolvedWorkspace = workspaces.first
        togglWorkspaceCatalogs = catalogs
        preferencesStore.storeResolvedWorkspace(workspaces.first)

        return catalogs
    }

    @discardableResult
    private func loadClockifyCatalogs() async throws -> [ClockifyWorkspaceCatalog] {
        guard !clockifyAPIToken.trimmed.isEmpty else {
            clearClockifyCatalogs()
            return []
        }

        isRefreshingClockifyWorkspaces = true
        defer { isRefreshingClockifyWorkspaces = false }

        let workspaces = try await clockifyService.fetchWorkspaces(apiKey: clockifyAPIToken.trimmed)
        var catalogs: [ClockifyWorkspaceCatalog] = []

        for workspace in workspaces {
            let projects = try await clockifyService.fetchProjects(
                apiKey: clockifyAPIToken.trimmed,
                workspaceID: workspace.id
            )
            catalogs.append(
                ClockifyWorkspaceCatalog(
                    workspace: workspace,
                    projects: projects
                )
            )
        }

        availableClockifyWorkspaces = workspaces
        resolvedClockifyWorkspace = workspaces.first
        clockifyWorkspaceCatalogs = catalogs
        preferencesStore.storeResolvedClockifyWorkspace(workspaces.first)

        return catalogs
    }

    @discardableResult
    private func loadHarvestCatalogs() async throws -> [HarvestAccountCatalog] {
        guard !harvestAccessToken.trimmed.isEmpty else {
            clearHarvestCatalogs()
            return []
        }

        isRefreshingHarvestAssignments = true
        defer { isRefreshingHarvestAssignments = false }

        let accounts = try await harvestService.fetchAccounts(accessToken: harvestAccessToken.trimmed)
        var catalogs: [HarvestAccountCatalog] = []

        for account in accounts {
            let projects = try await harvestService.fetchProjectAssignments(
                accessToken: harvestAccessToken.trimmed,
                accountID: account.id
            )
            catalogs.append(
                HarvestAccountCatalog(
                    account: account,
                    projects: projects
                )
            )
        }

        availableHarvestAccounts = accounts
        resolvedHarvestAccount = accounts.first
        availableHarvestProjects = catalogs.count == 1 ? (catalogs.first?.projects ?? []) : []
        resolvedHarvestProject = availableHarvestProjects.first
        resolvedHarvestTask = resolvedHarvestProject?.taskAssignments.first
        harvestAccountCatalogs = catalogs
        preferencesStore.storeResolvedHarvestAccount(accounts.first)
        preferencesStore.storeResolvedHarvestProject(resolvedHarvestProject)
        preferencesStore.storeResolvedHarvestTask(resolvedHarvestTask)

        return catalogs
    }

    private func loadTogglCatalogs(for workspaces: [WorkspaceSummary]) async throws -> [TogglWorkspaceCatalog] {
        var catalogs: [TogglWorkspaceCatalog] = []

        for workspace in workspaces {
            let projects = try await togglService.fetchProjects(
                apiToken: togglAPIToken.trimmed,
                workspaceID: workspace.id
            )
            catalogs.append(
                TogglWorkspaceCatalog(
                    workspace: workspace,
                    projects: projects
                )
            )
        }

        return catalogs
    }

    private func refreshTrackerReferenceData(showErrors: Bool) async -> LLMExtractionContext {
        if hasStoredCredential(for: .toggl) {
            do {
                _ = try await loadTogglCatalogs()
            } catch {
                if showErrors {
                    togglTestResult = InlineResult(message: error.localizedDescription, isError: true)
                }
            }
        } else {
            clearTogglCatalogs()
        }

        if hasStoredCredential(for: .clockify) {
            do {
                _ = try await loadClockifyCatalogs()
            } catch {
                if showErrors {
                    clockifyTestResult = InlineResult(message: error.localizedDescription, isError: true)
                }
            }
        } else {
            clearClockifyCatalogs()
        }

        if hasStoredCredential(for: .harvest) {
            do {
                _ = try await loadHarvestCatalogs()
            } catch {
                if showErrors {
                    harvestTestResult = InlineResult(message: error.localizedDescription, isError: true)
                }
            }
        } else {
            clearHarvestCatalogs()
        }

        return activeTrackerExtractionContext
    }

    private func validate(
        entries: [CandidateTimeEntry],
        context: LLMExtractionContext? = nil
    ) -> [CandidateTimeEntry] {
        let validationContext = context ?? activeTrackerExtractionContext
        let resolvedEntries = TrackerSelectionResolver.resolve(
            entries: entries,
            context: validationContext
        )

        return validator.validate(
            entries: resolvedEntries,
            enabledTrackers: enabledTimeTrackers,
            togglWorkspaces: validationContext.togglWorkspaces,
            clockifyWorkspaces: validationContext.clockifyWorkspaces,
            harvestAccounts: validationContext.harvestAccounts
        )
    }

    func prepareAppStorageExport(
        format: AppStorageExportFormat,
        startDate: Date,
        endDate: Date
    ) throws -> ExportPreparation {
        let range = normalizedExportRange(startDate: startDate, endDate: endDate)
        let entries = storedEntries.filter { range.contains($0.date) }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data: Data

        switch format {
        case .toggl:
            let exportEntries = try entries.map { record in
                guard let toggl = record.toggl else {
                    throw PlannerServiceError.emptyResponse(
                        "At least one stored entry does not contain a Toggl submission payload."
                    )
                }

                return TogglAppStorageExportEntry(
                    storedRecordID: record.id,
                    submittedAt: record.submittedAt,
                    workspaceID: toggl.workspaceID,
                    workspaceName: toggl.workspaceName,
                    request: toggl.request
                )
            }

            data = try encoder.encode(
                AppStorageExportEnvelope(
                    exportedAt: .now,
                    storageMode: isUsingICloudStorage ? "icloud" : "local",
                    format: format,
                    dateRange: .init(startDate: range.lowerBound, endDate: range.upperBound),
                    entries: exportEntries
                )
            )
        case .clockify:
            let exportEntries = try entries.map { record in
                guard let clockify = record.clockify else {
                    throw PlannerServiceError.emptyResponse(
                        "At least one stored entry does not contain a Clockify submission payload."
                    )
                }

                return ClockifyAppStorageExportEntry(
                    storedRecordID: record.id,
                    submittedAt: record.submittedAt,
                    workspaceID: clockify.workspaceID,
                    workspaceName: clockify.workspaceName,
                    request: clockify.request
                )
            }

            data = try encoder.encode(
                AppStorageExportEnvelope(
                    exportedAt: .now,
                    storageMode: isUsingICloudStorage ? "icloud" : "local",
                    format: format,
                    dateRange: .init(startDate: range.lowerBound, endDate: range.upperBound),
                    entries: exportEntries
                )
            )
        case .harvest:
            let exportEntries = try entries.map { record in
                guard let harvest = record.harvest else {
                    throw PlannerServiceError.emptyResponse(
                        "At least one stored entry does not contain a Harvest submission payload."
                    )
                }

                return HarvestAppStorageExportEntry(
                    storedRecordID: record.id,
                    submittedAt: record.submittedAt,
                    accountID: harvest.accountID,
                    accountName: harvest.accountName,
                    projectID: harvest.projectID,
                    projectName: harvest.projectName,
                    taskID: harvest.taskID,
                    taskName: harvest.taskName,
                    timestampRequest: harvest.timestampRequest,
                    durationFallbackRequest: harvest.durationFallbackRequest
                )
            }

            data = try encoder.encode(
                AppStorageExportEnvelope(
                    exportedAt: .now,
                    storageMode: isUsingICloudStorage ? "icloud" : "local",
                    format: format,
                    dateRange: .init(startDate: range.lowerBound, endDate: range.upperBound),
                    entries: exportEntries
                )
            )
        }

        return ExportPreparation(
            document: AppStorageExportDocument(data: data),
            filename: "\(AppConfiguration.exportFilenamePrefix)-\(format.rawValue)-\(exportFilenameDate(range.lowerBound))-\(exportFilenameDate(range.upperBound)).json"
        )
    }

    // MARK: - Submit entries

    func submitEntries() async {
        reviewErrorMessage = nil
        reviewStatusMessage = nil

        isSubmitting = true
        defer { isSubmitting = false }

        let validationContext = await refreshTrackerReferenceData(showErrors: false)
        draft.candidateEntries = validate(entries: draft.candidateEntries, context: validationContext)
        persistDraft()

        guard !draft.candidateEntries.contains(where: \.hasErrors) else {
            reviewErrorMessage = "Fix the validation errors before submitting."
            return
        }

        let submissionTime = Date.now

        do {
            storedEntries = try syncRepository.upsertStoredEntries(
                draft.candidateEntries.map { entry in
                    StoredTimeEntryRecord(
                        entry: entry,
                        submittedAt: submissionTime,
                        diaryPromptRecordID: draft.sourceDiaryPromptID
                    )
                }
            )
        } catch {
            reviewErrorMessage = error.localizedDescription
            return
        }

        var successfulDestinations = [appStorageDisplayName]
        var failures: [String] = []

        if hasStoredCredential(for: .toggl) {
            let submissions = storedEntries.compactMap(\.toggl)

            if submissions.count == draft.candidateEntries.count {
                do {
                    _ = try await togglService.createTimeEntries(
                        submissions,
                        apiToken: togglAPIToken.trimmed
                    )
                    successfulDestinations.append(TimeTrackerProvider.toggl.displayName)
                } catch {
                    failures.append("Toggl: \(error.localizedDescription)")
                }
            } else {
                failures.append("Toggl: Some entries are missing workspace assignments.")
            }
        }

        if hasStoredCredential(for: .clockify) {
            let submissions = storedEntries.compactMap(\.clockify)

            if submissions.count == draft.candidateEntries.count {
                do {
                    _ = try await clockifyService.createTimeEntries(
                        submissions,
                        apiKey: clockifyAPIToken.trimmed
                    )
                    successfulDestinations.append(TimeTrackerProvider.clockify.displayName)
                } catch {
                    failures.append("Clockify: \(error.localizedDescription)")
                }
            } else {
                failures.append("Clockify: Some entries are missing workspace assignments.")
            }
        }

        if hasStoredCredential(for: .harvest) {
            let submissions = storedEntries.compactMap(\.harvest)

            if submissions.count == draft.candidateEntries.count {
                do {
                    _ = try await harvestService.createTimeEntries(
                        submissions,
                        accessToken: harvestAccessToken.trimmed
                    )
                    successfulDestinations.append(TimeTrackerProvider.harvest.displayName)
                } catch {
                    failures.append("Harvest: \(error.localizedDescription)")
                }
            } else {
                failures.append("Harvest: Some entries are missing project or task assignments.")
            }
        }

        let successMessage = Self.submissionSummary(
            entryCount: draft.candidateEntries.count,
            destinations: successfulDestinations,
            appStorageDisplayName: appStorageDisplayName
        )

        if failures.isEmpty {
            draft = PlannerDraft.empty(on: currentDay)
            clearPersistedDraft()
            captureStatusMessage = successMessage
            navigateToCapture()
        } else {
            reviewStatusMessage = successMessage
            reviewErrorMessage = failures.joined(separator: " ")
        }
    }

    // MARK: - Private helpers

    private var currentDay: Date {
        Self.normalizedDay(.now, in: timeZone)
    }

    private var selectedExternalProviderConfiguration: LLMRequestConfiguration? {
        guard selectedProvider.isExternalProvider, isSelectedProviderConfigured else { return nil }

        return LLMRequestConfiguration(
            provider: selectedProvider,
            apiKey: activeAPIKey.trimmed,
            model: effectiveModel
        )
    }

    private var aiConfigurationErrorMessage: String {
        if selectedProvider == .disabled {
            guard isAppleIntelligenceEnabled else {
                return "Enable Apple Intelligence or choose a cloud AI provider in Settings before continuing."
            }

            return "Apple Intelligence is unavailable and no cloud AI provider is selected. Enable Apple Intelligence on this device or choose a cloud AI provider in Settings."
        }

        guard isAppleIntelligenceEnabled else {
            return "Add a \(selectedProvider.displayName) API key in Settings before continuing."
        }

        return "Apple Intelligence is unavailable and \(selectedProvider.displayName) is not configured. Add a \(selectedProvider.displayName) API key or make Apple Intelligence available on this device."
    }

    private func appleIntelligenceConfiguration(refreshIfNeeded: Bool) -> LLMRequestConfiguration? {
        guard isAppleIntelligenceEnabled else { return nil }

        if refreshIfNeeded || appleIntelligenceAvailability == .unknown {
            guard refreshAppleIntelligenceAvailability() else { return nil }
        }

        guard isAppleIntelligenceAvailable else { return nil }

        return LLMRequestConfiguration(
            provider: .appleFoundation,
            apiKey: "",
            model: LLMProvider.appleFoundation.defaultModel
        )
    }

    private func performPreferredLLMOperation<T>(
        _ operation: (LLMServicing, LLMRequestConfiguration) async throws -> T
    ) async throws -> (value: T, provider: LLMProvider, usedAppleFallback: Bool) {
        if let externalConfiguration = selectedExternalProviderConfiguration {
            do {
                let value = try await operation(
                    llmRouter.service(for: externalConfiguration.provider),
                    externalConfiguration
                )
                return (value, externalConfiguration.provider, false)
            } catch {
                guard shouldFallbackToApple(after: error),
                      let appleConfiguration = appleIntelligenceConfiguration(refreshIfNeeded: true) else {
                    throw error
                }

                let value = try await operation(
                    llmRouter.service(for: appleConfiguration.provider),
                    appleConfiguration
                )
                return (value, appleConfiguration.provider, true)
            }
        }

        guard let appleConfiguration = appleIntelligenceConfiguration(refreshIfNeeded: true) else {
            throw PlannerServiceError.emptyResponse(aiConfigurationErrorMessage)
        }

        let value = try await operation(
            llmRouter.service(for: appleConfiguration.provider),
            appleConfiguration
        )
        return (value, appleConfiguration.provider, false)
    }

    private func shouldFallbackToApple(after error: Error) -> Bool {
        if let urlError = error as? URLError {
            return [
                .timedOut,
                .cannotFindHost,
                .cannotConnectToHost,
                .dnsLookupFailed,
                .networkConnectionLost,
                .notConnectedToInternet
            ].contains(urlError.code)
        }

        guard let plannerError = error as? PlannerServiceError else {
            return false
        }

        switch plannerError {
        case .invalidResponse:
            return true
        case let .api(statusCode, _):
            return [408, 425, 429, 500, 502, 503, 504].contains(statusCode)
        case .missingCredential,
                .emptyResponse,
                .decoding,
                .noResolvedWorkspace,
                .noResolvedClockifyWorkspace,
                .noResolvedHarvestTarget,
                .partialSubmission:
            return false
        }
    }

    private func processSuccessMessage(
        entryCount: Int,
        provider: LLMProvider,
        usedAppleFallback: Bool
    ) -> String {
        if usedAppleFallback {
            return "Generated \(entryCount) candidate entries via \(provider.displayName) after \(selectedProvider.displayName) was unavailable."
        }

        return "Generated \(entryCount) candidate entries via \(provider.displayName)."
    }

    private func saveSecret(_ value: String, for key: KeychainKey) {
        if value.trimmed.isEmpty {
            keychainStore.removeValue(for: key)
        } else {
            keychainStore.set(value.trimmed, for: key)
        }
    }

    private func validateAndPersistEntries() {
        draft.candidateEntries = validate(entries: draft.candidateEntries)
        persistDraft()
    }

    private func updateDraftEntry(
        id: CandidateTimeEntry.ID,
        _ mutation: (inout CandidateTimeEntry) -> Void
    ) {
        guard let index = draft.candidateEntries.firstIndex(where: { $0.id == id }) else { return }

        var entry = draft.candidateEntries[index]
        mutation(&entry)
        entry.source = .user
        draft.candidateEntries[index] = entry
        validateAndPersistEntries()
    }

    private func buildTogglTarget(
        workspaceID: Int?,
        projectID: Int?
    ) -> CandidateTimeEntry.TogglTarget? {
        let resolvedProject = projectID.flatMap { projectID in
            togglWorkspaceCatalogs.lazy
                .flatMap(\.projects)
                .first(where: { $0.id == projectID })
        }
        let resolvedWorkspace = workspaceID.flatMap { workspaceID in
            togglWorkspaceCatalogs.first(where: { $0.workspace.id == workspaceID })
        } ?? resolvedProject.flatMap { project in
            togglWorkspaceCatalogs.first(where: { $0.workspace.id == project.workspaceId })
        }

        let target = CandidateTimeEntry.TogglTarget(
            workspaceName: resolvedWorkspace?.workspace.name,
            workspaceId: resolvedWorkspace?.workspace.id,
            projectName: resolvedProject?.name,
            projectId: resolvedProject?.id
        )

        return target.hasSelection ? target : nil
    }

    private func buildClockifyTarget(
        workspaceID: String?,
        projectID: String?
    ) -> CandidateTimeEntry.ClockifyTarget? {
        let resolvedProject = projectID.flatMap { projectID in
            clockifyWorkspaceCatalogs.lazy
                .flatMap(\.projects)
                .first(where: { $0.id == projectID })
        }
        let resolvedWorkspace = workspaceID.flatMap { workspaceID in
            clockifyWorkspaceCatalogs.first(where: { $0.workspace.id == workspaceID })
        } ?? resolvedProject.flatMap { project in
            clockifyWorkspaceCatalogs.first(where: { $0.workspace.id == project.workspaceId })
        }

        let target = CandidateTimeEntry.ClockifyTarget(
            workspaceName: resolvedWorkspace?.workspace.name,
            workspaceId: resolvedWorkspace?.workspace.id,
            projectName: resolvedProject?.name,
            projectId: resolvedProject?.id
        )

        return target.hasSelection ? target : nil
    }

    private func buildHarvestTarget(
        accountID: Int?,
        projectID: Int?,
        taskID: Int?
    ) -> CandidateTimeEntry.HarvestTarget? {
        let resolvedProject = projectID.flatMap { projectID in
            harvestAccountCatalogs.lazy
                .flatMap(\.projects)
                .first(where: { $0.id == projectID })
        }
        let resolvedAccount = accountID.flatMap { accountID in
            harvestAccountCatalogs.first(where: { $0.account.id == accountID })
        } ?? resolvedProject.flatMap { project in
            harvestAccountCatalogs.first(where: { account in
                account.projects.contains(where: { $0.id == project.id })
            })
        } ?? taskID.flatMap { taskID in
            harvestAccountCatalogs.first(where: { account in
                account.projects.contains(where: { project in
                    project.taskAssignments.contains(where: { $0.id == taskID })
                })
            })
        }
        let resolvedProjectFromTask = taskID.flatMap { taskID in
            harvestAccountCatalogs.lazy
                .flatMap(\.projects)
                .first(where: { project in
                    project.taskAssignments.contains(where: { $0.id == taskID })
                })
        }
        let finalProject = resolvedProject ?? resolvedProjectFromTask
        let resolvedTask = taskID.flatMap { taskID in
            harvestAccountCatalogs.lazy
                .flatMap(\.projects)
                .flatMap(\.taskAssignments)
                .first(where: { $0.id == taskID })
        }

        let target = CandidateTimeEntry.HarvestTarget(
            accountName: resolvedAccount?.account.name,
            accountId: resolvedAccount?.account.id,
            projectName: finalProject?.name,
            projectId: finalProject?.id,
            taskName: resolvedTask?.name,
            taskId: resolvedTask?.id
        )

        return target.hasSelection ? target : nil
    }

    private func navigateToCapture() {
        pendingReviewEntryID = nil
        selectedTab = .capture
    }

    private func navigateToReview(entryID: CandidateTimeEntry.ID?) {
        pendingReviewEntryID = entryID
        selectedTab = .review
    }

    private func loadPersistedContent() {
        do {
            let snapshot = try syncRepository.loadSnapshot(currentDay: currentDay)
            if let loadedDraft = snapshot.draft {
                draft = loadedDraft
                draft.candidateEntries = validate(entries: draft.candidateEntries)
            } else {
                draft = PlannerDraft.empty(on: currentDay)
            }
            diaryPromptHistory = snapshot.diaryPromptHistory.sorted { $0.createdAt < $1.createdAt }
            storedEntries = snapshot.storedEntries.sorted { $0.start < $1.start }
        } catch {
            captureErrorMessage = error.localizedDescription
        }

        synchronizeNoteDateWithToday()
    }

    private func persistDraft(immediately: Bool = true) {
        pendingDraftPersistenceTask?.cancel()

        if immediately {
            persistDraftNow()
            return
        }

        hasPendingDraftPersistence = true
        pendingDraftPersistenceTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                try await Task.sleep(for: AppConfiguration.draftSyncDebounceInterval)
            } catch {
                self.hasPendingDraftPersistence = false
                return
            }

            self.persistDraftNow()
        }
    }

    private func persistDraftNow() {
        pendingDraftPersistenceTask?.cancel()
        pendingDraftPersistenceTask = nil
        hasPendingDraftPersistence = false

        do {
            try syncRepository.saveDraft(draft)
        } catch {
            captureErrorMessage = error.localizedDescription
        }
    }

    private func clearPersistedDraft() {
        pendingDraftPersistenceTask?.cancel()
        pendingDraftPersistenceTask = nil
        hasPendingDraftPersistence = false

        do {
            try syncRepository.clearDraft()
        } catch {
            captureErrorMessage = error.localizedDescription
        }
    }

    private func flushPendingDraftPersistence() {
        guard hasPendingDraftPersistence else { return }
        persistDraftNow()
    }

    private func archiveCurrentPromptIfNeeded() {
        guard !draft.note.rawText.isBlank else { return }

        let record = DiaryPromptRecord(
            day: currentDay,
            rawText: draft.note.rawText
        )

        if let latestRecord = diaryPromptHistory.last,
           latestRecord.day == record.day,
           latestRecord.rawText == record.rawText {
            draft.sourceDiaryPromptID = latestRecord.id
            return
        }

        do {
            diaryPromptHistory = try syncRepository.appendDiaryPrompt(record)
            draft.sourceDiaryPromptID = resolveArchivedDiaryPromptID(
                preferredID: record.id,
                day: record.day,
                rawText: record.rawText,
                history: diaryPromptHistory
            )
        } catch {
            captureErrorMessage = error.localizedDescription
        }
    }

    func latestStoredEntries(for diaryPromptID: UUID) -> [StoredTimeEntryRecord] {
        let matches = storedEntries.filter { $0.diaryPromptRecordID == diaryPromptID }
        guard let latestSubmissionTime = matches.map(\.submittedAt).max() else { return [] }

        return matches
            .filter { $0.submittedAt == latestSubmissionTime }
            .sorted { lhs, rhs in
                if lhs.start == rhs.start {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.start < rhs.start
            }
    }

    func activeDraftEntries(for diaryPromptID: UUID) -> [CandidateTimeEntry] {
        guard draft.sourceDiaryPromptID == diaryPromptID else { return [] }
        return draft.candidateEntries.sorted { lhs, rhs in
            if lhs.start == rhs.start {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.start < rhs.start
        }
    }

    /// Updates the note's input date to today so the UI banner stays current.
    /// Does NOT shift candidate entry dates — entries keep the date determined by the LLM
    /// (which may be yesterday or another referenced day).
    private func synchronizeNoteDateWithToday() {
        let today = currentDay
        guard draft.note.date != today else { return }

        draft.note.date = today
    }

    private static func normalizedDay(_ date: Date, in timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.startOfDay(for: date)
    }

    private func normalizedExportRange(startDate: Date, endDate: Date) -> ClosedRange<Date> {
        let lower = Self.normalizedDay(min(startDate, endDate), in: timeZone)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let upperDay = Self.normalizedDay(max(startDate, endDate), in: timeZone)
        let exclusiveUpper = calendar.date(byAdding: .day, value: 1, to: upperDay) ?? upperDay
        let inclusiveUpper = exclusiveUpper.addingTimeInterval(-1)

        return lower...inclusiveUpper
    }

    private func exportFilenameDate(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func commaSeparatedList(_ values: [String]) -> String {
        switch values.count {
        case 0:
            return ""
        case 1:
            return values[0]
        case 2:
            return "\(values[0]) and \(values[1])"
        default:
            let prefix = values.dropLast().joined(separator: ", ")
            return "\(prefix), and \(values.last!)"
        }
    }

    private static func submissionSummary(
        entryCount: Int,
        destinations: [String],
        appStorageDisplayName: String
    ) -> String {
        let externalDestinations = destinations.filter { $0 != appStorageDisplayName }

        if externalDestinations.isEmpty {
            return "Saved \(entryCount) entries to \(appStorageDisplayName)."
        }

        return "Saved \(entryCount) entries to \(appStorageDisplayName) and submitted them to \(commaSeparatedList(externalDestinations))."
    }

    private func resolveArchivedDiaryPromptID(
        preferredID: UUID,
        day: Date,
        rawText: String,
        history: [DiaryPromptRecord]
    ) -> UUID? {
        if history.contains(where: { $0.id == preferredID }) {
            return preferredID
        }

        return history
            .filter { $0.day == day && $0.rawText == rawText }
            .max { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.createdAt < rhs.createdAt
            }?
            .id
    }
}
