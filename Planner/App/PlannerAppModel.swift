import Foundation
import SwiftUI
import Combine

@MainActor
final class PlannerAppModel: ObservableObject {
    enum Tab: Hashable {
        case capture
        case review
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

    // MARK: - Navigation

    @Published var selectedTab: Tab = .capture
    @Published var selectedSettingsTab: SettingsTab = .aiProvider

    // MARK: - Draft

    @Published private(set) var draft: PlannerDraft

    // MARK: - Toggl data

    @Published private(set) var availableWorkspaces: [WorkspaceSummary] = []
    @Published private(set) var availableProjects: [ProjectSummary] = []
    @Published private(set) var resolvedWorkspace: WorkspaceSummary?

    // MARK: - LLM provider

    @Published var selectedProvider: LLMProvider {
        didSet { preferencesStore.selectedLLMProvider = selectedProvider }
    }
    @Published var llmModel: String {
        didSet {
            preferencesStore.setLLMModel(llmModel.trimmed.nilIfBlank, for: selectedProvider)
        }
    }
    @Published var selectedTimeTracker: TimeTrackerProvider {
        didSet { preferencesStore.selectedTimeTracker = selectedTimeTracker }
    }

    // MARK: - API keys (per-provider)

    @Published var geminiAPIKey: String
    @Published var claudeAPIKey: String
    @Published var openAIAPIKey: String
    @Published var togglAPIToken: String

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
    /// Inline feedback for the polish user context button.
    @Published var polishResult: InlineResult?

    // MARK: - Loading states

    @Published var isProcessing = false
    @Published var isSubmitting = false
    @Published var isRefreshingWorkspaces = false
    @Published var isTestingLLM = false
    @Published var isTestingToggl = false
    @Published var isPolishingContext = false
    @Published var shouldConfirmRegeneration = false

    // MARK: - Dependencies

    private let preferencesStore: PreferencesStore
    private let draftStore: DraftStore
    private let keychainStore: KeychainStoring
    private let llmRouter: LLMServiceRouter
    private let togglService: TogglServicing
    private let validator: TimeEntryValidating
    private let timeZone: TimeZone
    private var didStart = false

    init(
        preferencesStore: PreferencesStore,
        draftStore: DraftStore,
        keychainStore: KeychainStoring,
        llmRouter: LLMServiceRouter,
        togglService: TogglServicing,
        validator: TimeEntryValidating? = nil,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        self.preferencesStore = preferencesStore
        self.draftStore = draftStore
        self.keychainStore = keychainStore
        self.llmRouter = llmRouter
        self.togglService = togglService
        self.validator = validator ?? TimeEntryValidator()
        self.timeZone = timeZone

        self.draft = PlannerDraft.empty(on: Self.normalizedDay(Date.now, in: timeZone))
        self.geminiAPIKey = keychainStore.string(for: .geminiAPIKey) ?? ""
        self.claudeAPIKey = keychainStore.string(for: .claudeAPIKey) ?? ""
        self.openAIAPIKey = keychainStore.string(for: .openAIAPIKey) ?? ""
        self.togglAPIToken = keychainStore.string(for: .togglAPIToken) ?? ""
        let initialProvider = preferencesStore.selectedLLMProvider
        self.selectedProvider = initialProvider
        self.llmModel = preferencesStore.llmModel(for: initialProvider) ?? initialProvider.defaultModel
        self.selectedTimeTracker = preferencesStore.selectedTimeTracker
        self.userContext = preferencesStore.userContext

        loadPersistedDraft()
    }

    static func live() -> PlannerAppModel {
        let httpClient = URLSessionHTTPClient()
        let geminiService = GeminiService(httpClient: httpClient)
        let claudeService = ClaudeService(httpClient: httpClient)
        let openAIService = OpenAIService(httpClient: httpClient)

        return PlannerAppModel(
            preferencesStore: PreferencesStore(),
            draftStore: DraftStore(),
            keychainStore: KeychainStore(),
            llmRouter: LLMServiceRouter(
                geminiService: geminiService,
                claudeService: claudeService,
                openAIService: openAIService
            ),
            togglService: TogglService(httpClient: httpClient)
        )
    }

    // MARK: - Computed properties

    /// The API key for the currently selected LLM provider.
    var activeAPIKey: String {
        switch selectedProvider {
        case .gemini: geminiAPIKey
        case .claude: claudeAPIKey
        case .openAI: openAIAPIKey
        }
    }

    /// The effective model, falling back to the provider's default.
    var effectiveModel: String {
        llmModel.trimmed.nilIfBlank ?? selectedProvider.defaultModel
    }

    var canProcess: Bool {
        !draft.note.rawText.isBlank && !activeAPIKey.trimmed.isEmpty && !isProcessing
    }

    var canSubmit: Bool {
        !draft.candidateEntries.isEmpty && selectedTimeTracker == .toggl && !togglAPIToken.trimmed.isEmpty && !isSubmitting
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

    // MARK: - Lifecycle

    func start() async {
        guard !didStart else { return }
        didStart = true
        synchronizeNoteDateWithToday()

        if !togglAPIToken.trimmed.isEmpty {
            _ = await refreshWorkspaces(showErrors: false)
        }
    }

    // MARK: - Note editing

    func updateRawText(_ rawText: String) {
        synchronizeNoteDateWithToday()
        draft.note.rawText = rawText
        draft.note.updatedAt = .now
        persistDraft()
    }

    // MARK: - API key management

    func updateAPIKey(_ value: String, for provider: LLMProvider) {
        switch provider {
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
            availableWorkspaces = []
            availableProjects = []
            resolvedWorkspace = nil
        }
    }

    func updateSelectedProvider(_ provider: LLMProvider) {
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

    func updateSelectedTimeTracker(_ tracker: TimeTrackerProvider) {
        guard tracker.isAvailable else { return }
        // Defer the change to avoid publishing within a view update cycle.
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.selectedTimeTracker = tracker
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

    // MARK: - Draft management

    func clearDraft() {
        synchronizeNoteDateWithToday()
        draft = PlannerDraft.empty(on: currentDay)
        captureStatusMessage = nil
        captureErrorMessage = nil
        reviewStatusMessage = nil
        reviewErrorMessage = nil
        persistDraft()
    }

    // MARK: - Note processing

    func processNote(replacingExistingEntries: Bool = false) async {
        captureErrorMessage = nil
        captureStatusMessage = nil
        synchronizeNoteDateWithToday()

        guard !activeAPIKey.trimmed.isEmpty else {
            captureErrorMessage = "Add a \(selectedProvider.displayName) API key in Settings before processing notes."
            return
        }

        if !replacingExistingEntries, !draft.candidateEntries.isEmpty {
            shouldConfirmRegeneration = true
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        if !togglAPIToken.trimmed.isEmpty {
            _ = await refreshWorkspaces(showErrors: false)
        }

        do {
            let service = llmRouter.service(for: selectedProvider)
            let response = try await service.extractTimeEntries(
                apiKey: activeAPIKey.trimmed,
                model: effectiveModel,
                note: draft.note,
                timeZone: timeZone,
                userContext: userContext.trimmed.nilIfBlank,
                availableProjects: availableProjects.map(\.name)
            )

            var entries = try GeminiEntryConverter.convert(
                response: response,
                selectedDate: draft.note.date,
                timeZone: timeZone
            )

            if !availableProjects.isEmpty {
                entries = ProjectMatcher.assignProjects(from: availableProjects, to: entries)
            }

            // If the workspace has exactly one project, auto-assign it to any entries
            // that the AI didn't already pick a project for.
            if availableProjects.count == 1, let onlyProject = availableProjects.first {
                entries = entries.map { entry in
                    guard entry.projectId == nil else { return entry }
                    var copy = entry
                    copy.projectName = onlyProject.name
                    copy.projectId = onlyProject.id
                    copy.workspaceId = onlyProject.workspaceId
                    return copy
                }
            }

            draft.summary = response.summary?.trimmed.nilIfBlank
            draft.assumptions = response.assumptions.map(\.trimmed).filter { !$0.isEmpty }
            draft.lastProcessedAt = .now
            draft.candidateEntries = validator.validate(entries: entries, submissionWorkspaceID: nil)
            persistDraft()

            captureStatusMessage = "Generated \(draft.candidateEntries.count) candidate entries via \(selectedProvider.displayName)."
            selectedTab = .review
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

    // MARK: - Connection testing

    func testLLMConnection() async {
        llmTestResult = nil

        guard !activeAPIKey.trimmed.isEmpty else {
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
            llmTestResult = InlineResult(message: "\(selectedProvider.displayName) connected (\(status)).", isError: false)
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
            let workspace = await refreshWorkspaces(showErrors: true)
            if let workspace {
                let name = user.fullname?.trimmed.nilIfBlank ?? user.email?.trimmed.nilIfBlank ?? "User"
                togglTestResult = InlineResult(message: "Connected as \(name) — workspace: \(workspace.name).", isError: false)
            }
        } catch {
            togglTestResult = InlineResult(message: error.localizedDescription, isError: true)
        }
    }

    // MARK: - Magic wand (polish user context)

    func polishUserContext() async {
        polishResult = nil

        guard !activeAPIKey.trimmed.isEmpty else {
            polishResult = InlineResult(message: "Add a \(selectedProvider.displayName) API key to use the polish feature.", isError: true)
            return
        }

        guard !userContext.isBlank else {
            polishResult = InlineResult(message: "Write something about yourself first.", isError: true)
            return
        }

        isPolishingContext = true
        defer { isPolishingContext = false }

        do {
            let service = llmRouter.service(for: selectedProvider)
            let polished = try await service.polishUserContext(
                apiKey: activeAPIKey.trimmed,
                model: effectiveModel,
                rawText: userContext
            )
            userContext = polished
            polishResult = InlineResult(message: "Polished successfully.", isError: false)
        } catch {
            polishResult = InlineResult(message: error.localizedDescription, isError: true)
        }
    }

    // MARK: - Workspace management

    @discardableResult
    func refreshWorkspaces(showErrors: Bool) async -> WorkspaceSummary? {
        guard !togglAPIToken.trimmed.isEmpty else {
            availableWorkspaces = []
            availableProjects = []
            resolvedWorkspace = nil
            preferencesStore.storeResolvedWorkspace(nil)
            if showErrors {
                togglTestResult = InlineResult(message: "Add a Toggl API token before loading workspaces.", isError: true)
            }
            return nil
        }

        isRefreshingWorkspaces = true
        defer { isRefreshingWorkspaces = false }

        do {
            let workspaces = try await togglService.fetchWorkspaces(apiToken: togglAPIToken.trimmed)
            availableWorkspaces = workspaces

            let resolved = WorkspaceSelectionResolver.resolve(
                savedWorkspaceID: preferencesStore.selectedWorkspaceID,
                fetchedWorkspaces: workspaces
            )

            resolvedWorkspace = resolved
            preferencesStore.storeResolvedWorkspace(resolved)

            if let resolved {
                await refreshProjects(for: resolved)
            } else {
                availableProjects = []
            }

            if showErrors, resolved == nil {
                togglTestResult = InlineResult(message: "Toggl returned no workspaces for this token.", isError: true)
            }

            return resolved
        } catch {
            if showErrors {
                togglTestResult = InlineResult(message: error.localizedDescription, isError: true)
            }
            return nil
        }
    }

    func selectWorkspace(id: Int?) {
        guard let id,
              let workspace = availableWorkspaces.first(where: { $0.id == id }) else {
            return
        }

        resolvedWorkspace = workspace
        preferencesStore.storeResolvedWorkspace(workspace)

        Task {
            await refreshProjects(for: workspace)
        }
    }

    // MARK: - Submit entries

    func submitEntries() async {
        reviewErrorMessage = nil
        reviewStatusMessage = nil

        guard selectedTimeTracker == .toggl else {
            reviewErrorMessage = "\(selectedTimeTracker.displayName) support will be added in a future version."
            return
        }

        guard !togglAPIToken.trimmed.isEmpty else {
            reviewErrorMessage = "Add a \(selectedTimeTracker.credentialLabel) in Settings before submitting."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        guard let workspace = await refreshWorkspaces(showErrors: false) else {
            reviewErrorMessage = PlannerServiceError.noResolvedWorkspace.localizedDescription
            return
        }

        draft.candidateEntries = validator.validate(
            entries: draft.candidateEntries,
            submissionWorkspaceID: workspace.id
        )
        persistDraft()

        guard !draft.candidateEntries.contains(where: \.hasErrors) else {
            reviewErrorMessage = "Fix the validation errors before submitting to \(selectedTimeTracker.displayName)."
            return
        }

        let payloads = draft.candidateEntries.map { TogglTimeEntryCreateRequest.make(from: $0, workspaceID: workspace.id) }

        do {
            _ = try await togglService.createTimeEntries(
                payloads,
                apiToken: togglAPIToken.trimmed,
                workspaceID: workspace.id
            )

            let message = "Submitted \(payloads.count) entries to \(selectedTimeTracker.displayName) workspace \(workspace.name)."
            draft = PlannerDraft.empty(on: currentDay)
            persistDraft()
            captureStatusMessage = message
            selectedTab = .capture
        } catch {
            reviewErrorMessage = error.localizedDescription
        }
    }

    // MARK: - Private helpers

    private var currentDay: Date {
        Self.normalizedDay(.now, in: timeZone)
    }

    private func refreshProjects(for workspace: WorkspaceSummary) async {
        do {
            let projects = try await togglService.fetchProjects(
                apiToken: togglAPIToken.trimmed,
                workspaceID: workspace.id
            )
            availableProjects = projects
        } catch {
            availableProjects = []
        }
    }

    private func saveSecret(_ value: String, for key: KeychainKey) {
        if value.trimmed.isEmpty {
            keychainStore.removeValue(for: key)
        } else {
            keychainStore.set(value.trimmed, for: key)
        }
    }

    private func validateAndPersistEntries() {
        draft.candidateEntries = validator.validate(entries: draft.candidateEntries, submissionWorkspaceID: nil)
        persistDraft()
    }

    private func loadPersistedDraft() {
        guard let loadedDraft = try? draftStore.loadLatestDraft() else { return }
        draft = loadedDraft
        synchronizeNoteDateWithToday()
        draft.candidateEntries = validator.validate(entries: draft.candidateEntries, submissionWorkspaceID: nil)
    }

    private func persistDraft() {
        do {
            try draftStore.save(draft)
        } catch {
            captureErrorMessage = error.localizedDescription
        }
    }

    /// Updates the note's input date to today so the UI banner stays current.
    /// Does NOT shift candidate entry dates — entries keep the date determined by the LLM
    /// (which may be yesterday or another referenced day).
    private func synchronizeNoteDateWithToday() {
        let today = currentDay
        guard draft.note.date != today else { return }

        draft.note.date = today
        draft.note.updatedAt = .now
    }

    private static func normalizedDay(_ date: Date, in timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.startOfDay(for: date)
    }
}
