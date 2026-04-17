import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var appModel: PlannerAppModel

    var body: some View {
        #if os(macOS)
        TabView(selection: $appModel.selectedSettingsTab) {
            LLMSettingsTabView()
                .tabItem {
                    Label("AI Provider", systemImage: "cpu")
                }
                .tag(PlannerAppModel.SettingsTab.aiProvider)

            TimeTrackerSettingsTabView()
                .tabItem {
                    Label("Time Tracker", systemImage: "timer")
                }
                .tag(PlannerAppModel.SettingsTab.timeTracker)

            AboutMeSettingsTabView()
                .tabItem {
                    Label("About Me", systemImage: "person.crop.circle")
                }
                .tag(PlannerAppModel.SettingsTab.aboutMe)
        }
        .frame(width: 520, height: 460)
        #else
        VStack(spacing: 16) {
            Picker("Section", selection: $appModel.selectedSettingsTab) {
                Text("AI Provider").tag(PlannerAppModel.SettingsTab.aiProvider)
                Text("Time Tracker").tag(PlannerAppModel.SettingsTab.timeTracker)
                Text("About Me").tag(PlannerAppModel.SettingsTab.aboutMe)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Group {
                switch appModel.selectedSettingsTab {
                case .aiProvider:
                    LLMSettingsTabView()
                case .timeTracker:
                    TimeTrackerSettingsTabView()
                case .aboutMe:
                    AboutMeSettingsTabView()
                }
            }
        }
        #endif
    }
}

// MARK: - Inline Result Label

/// Small inline feedback label shown next to a button after an action completes.
private struct InlineResultLabel: View {
    let result: PlannerAppModel.InlineResult

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: result.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .font(.caption)
            Text(result.message)
                .font(.caption)
                .lineLimit(2)
        }
        .foregroundStyle(result.isError ? .red : .green)
    }
}

private struct LLMSettingsTabView: View {
    @EnvironmentObject private var appModel: PlannerAppModel

    private var aiProviderColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 110), spacing: 8)]
    }

    private var appleIntelligenceSettingsURL: URL? {
        #if os(macOS)
        URL(string: "x-apple.systempreferences:com.apple.Siri")
        #else
        nil
        #endif
    }

    var body: some View {
        Form {
            Section("Apple Intelligence") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("If Apple Intelligence is enabled on your device, Tajnica s.p. can use it as the AI. Apple Intelligence consists of both on-device models and connected external models.")

                    if let appleIntelligenceSettingsURL {
                        Link("Open Apple Intelligence & Siri in System Settings", destination: appleIntelligenceSettingsURL)
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                if appModel.isAppleIntelligenceAvailable {
                    Toggle("Enable Apple Intelligence", isOn: $appModel.isAppleIntelligenceEnabled)

                    Text(
                        appModel.isAppleIntelligenceEnabled
                            ? "Apple Intelligence is available on this device and can be used as a local fallback."
                            : "Apple Intelligence is available on this device but will not be used until you turn it back on."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } else if let result = appModel.appleIntelligenceResult {
                    InlineResultLabel(result: result)
                } else {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Checking Apple Intelligence availability...")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("External LLM Providers") {
                Text("The selected external provider is used as the primary option. If Apple Intelligence is enabled, Tajnica s.p. falls back to it when the external provider is unavailable.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: aiProviderColumns, spacing: 8) {
                    ForEach(LLMProvider.selectableExternalProviders) { provider in
                        Button {
                            appModel.updateSelectedProvider(provider)
                        } label: {
                            Text(provider.shortName)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    appModel.selectedProvider == provider
                                        ? Color.accentColor.opacity(0.18)
                                        : Color.secondary.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )
                                .foregroundStyle(
                                    appModel.selectedProvider == provider ? Color.accentColor : Color.primary
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(appModel.selectedProvider.tradeoffSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if appModel.selectedProvider.isExternalProvider {
                Section(appModel.selectedProvider.configurationSectionTitle) {
                    if appModel.selectedProvider.requiresAPIKey {
                        SecureField(
                            appModel.selectedProvider.apiKeyLabel,
                            text: Binding(
                                get: { appModel.activeAPIKey },
                                set: { appModel.updateAPIKey($0, for: appModel.selectedProvider) }
                            )
                        )
                    }

                    if appModel.selectedProvider.supportsCustomModelSelection {
                        TextField(
                            "Model",
                            text: Binding(
                                get: { appModel.llmModel },
                                set: { appModel.updateLLMModel($0) }
                            )
                        )
                    }

                    if let hint = appModel.selectedProvider.configurationHint {
                        Text(hint)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        Button("Test Connection") {
                            Task {
                                await appModel.testLLMConnection()
                            }
                        }
                        .disabled(!appModel.canTestLLMProvider)

                        if appModel.isTestingLLM {
                            ProgressView()
                                .controlSize(.small)
                        }

                        if let result = appModel.llmTestResult {
                            InlineResultLabel(result: result)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
        .task {
            appModel.refreshAppleIntelligenceAvailability()
        }
    }
}

private struct TimeTrackerSettingsTabView: View {
    @EnvironmentObject private var appModel: PlannerAppModel
    @State private var credentialProvider: TimeTrackerProvider?
    @State private var credentialDraft = ""
    @State private var isShowingExportRangeSheet = false
    @State private var exportFormat: AppStorageExportFormat = .toggl
    @State private var exportStartDate = Date.now
    @State private var exportEndDate = Date.now
    @State private var exportDocument = AppStorageExportDocument(data: Data("{}".utf8))
    @State private var exportFilename = "planner-time-tracker.json"
    @State private var isPresentingExporter = false
    @State private var exportResult: PlannerAppModel.InlineResult?
    @State private var hasInitializedExportDates = false

    private var iCloudSettingsURL: URL? {
        #if os(macOS)
        URL(string: "x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings")
        #else
        nil
        #endif
    }

    var body: some View {
        Form {
            Section("App Storage") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(appModel.appStorageStatusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if !appModel.isUsingICloudStorage, let iCloudSettingsURL {
                        Link("Open iCloud Settings", destination: iCloudSettingsURL)
                            .font(.footnote)
                    }
                }

                Button("Export Data") {
                    if !hasInitializedExportDates {
                        exportStartDate = appModel.defaultExportStartDate
                        exportEndDate = appModel.defaultExportEndDate
                        exportFormat = appModel.defaultExportFormat
                        hasInitializedExportDates = true
                    }
                    isShowingExportRangeSheet = true
                }

                if let exportResult {
                    InlineResultLabel(result: exportResult)
                }
            }

            Section("External Time Trackers") {
                Text("\(appModel.appStorageDisplayName) is always saved on submit. Every external tracker with a valid connection receives the same submitted entries.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                timeTrackerCard(.toggl)
                timeTrackerCard(.clockify)
                timeTrackerCard(.harvest)
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
        .task(id: appModel.selectedSettingsTab) {
            guard appModel.selectedSettingsTab == .timeTracker else { return }

            if !hasInitializedExportDates {
                exportStartDate = appModel.defaultExportStartDate
                exportEndDate = appModel.defaultExportEndDate
                exportFormat = appModel.defaultExportFormat
                hasInitializedExportDates = true
            }

            await appModel.refreshTimeTrackerConnectionsOnViewLoad()
        }
        .sheet(item: $credentialProvider) { provider in
            TimeTrackerCredentialSheet(
                provider: provider,
                credentialText: $credentialDraft,
                onCancel: {
                    credentialProvider = nil
                    credentialDraft = ""
                },
                onConnect: {
                    let credential = credentialDraft
                    credentialProvider = nil
                    credentialDraft = ""

                    Task {
                        await appModel.storeTimeTrackerCredential(credential, for: provider)
                    }
                }
            )
        }
        .sheet(isPresented: $isShowingExportRangeSheet) {
            ExportRangeSheet(
                format: $exportFormat,
                startDate: $exportStartDate,
                endDate: $exportEndDate,
                onCancel: {
                    isShowingExportRangeSheet = false
                },
                onExport: {
                    do {
                        let preparation = try appModel.prepareAppStorageExport(
                            format: exportFormat,
                            startDate: exportStartDate,
                            endDate: exportEndDate
                        )
                        exportDocument = preparation.document
                        exportFilename = preparation.filename
                        exportResult = nil
                        isShowingExportRangeSheet = false
                        isPresentingExporter = true
                    } catch {
                        exportResult = .init(message: error.localizedDescription, isError: true)
                        isShowingExportRangeSheet = false
                    }
                }
            )
        }
        .fileExporter(
            isPresented: $isPresentingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success:
                exportResult = .init(message: "Export finished successfully.", isError: false)
            case let .failure(error):
                exportResult = .init(message: error.localizedDescription, isError: true)
            }
        }
    }

    @ViewBuilder
    private func timeTrackerCard(_ provider: TimeTrackerProvider) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(provider.displayName)
                    .font(.headline)

                Spacer()

                if appModel.hasStoredCredential(for: provider) {
                    Button(provider.disconnectButtonTitle, role: .destructive) {
                        appModel.disconnectTimeTracker(provider)
                    }
                    .controlSize(.small)
                } else {
                    Button(provider.dialogButtonTitle) {
                        credentialDraft = ""
                        credentialProvider = provider
                    }
                    .controlSize(.small)
                }
            }

            if appModel.hasStoredCredential(for: provider) {
                Text("API token saved in Keychain.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text(provider.connectInstructions)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if appModel.isTestingTimeTracker(provider) {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(appModel.testingMessage(for: provider))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if let result = appModel.testResult(for: provider) {
                InlineResultLabel(result: result)
            }

            if let summary = trackerReferenceSummary(for: provider) {
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func trackerReferenceSummary(for provider: TimeTrackerProvider) -> String? {
        switch provider {
        case .toggl:
            guard appModel.hasStoredCredential(for: .toggl) else { return nil }
            if appModel.togglWorkspaceCatalogs.isEmpty {
                return "Per-entry Toggl targets are resolved from the connected workspaces and projects after a successful refresh."
            }
            return "Loaded \(appModel.togglWorkspaceCatalogs.count) workspace(s) and \(appModel.totalTogglProjectCount) project(s). \(AppConfiguration.displayName) resolves per-entry Toggl targets in Review and skips trivial single-choice selections."
        case .clockify:
            guard appModel.hasStoredCredential(for: .clockify) else { return nil }
            if appModel.clockifyWorkspaceCatalogs.isEmpty {
                return "Per-entry Clockify targets are resolved from the connected workspaces and projects after a successful refresh."
            }
            return "Loaded \(appModel.clockifyWorkspaceCatalogs.count) workspace(s) and \(appModel.totalClockifyProjectCount) project(s). \(AppConfiguration.displayName) resolves per-entry Clockify targets in Review and skips trivial single-choice selections."
        case .harvest:
            guard appModel.hasStoredCredential(for: .harvest) else { return nil }
            if appModel.harvestAccountCatalogs.isEmpty {
                return "Per-entry Harvest account, project, and task targets are resolved after a successful refresh."
            }
            return "Loaded \(appModel.harvestAccountCatalogs.count) account(s), \(appModel.totalHarvestProjectCount) project(s), and \(appModel.totalHarvestTaskCount) task(s). \(AppConfiguration.displayName) resolves per-entry Harvest targets in Review and skips trivial single-choice selections."
        }
    }
}

private struct AboutMeSettingsTabView: View {
    @EnvironmentObject private var appModel: PlannerAppModel

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tell the AI about yourself so it can better predict your schedule.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ZStack(alignment: .topLeading) {
                        TextEditor(
                            text: $appModel.userContext
                        )
                        .font(.body)
                        .frame(minHeight: 180)
                        .scrollContentBackground(.hidden)

                        if appModel.userContext.isEmpty {
                            Text("Example: I work as a software engineer, usually 9am-6pm with a lunch break around noon. I work on projects Alpha and Beta, and have a daily standup at 9:15am. Most of my work is billable except for internal meetings...")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    HStack(spacing: 8) {
                        Spacer()

                        if let result = appModel.polishResult {
                            InlineResultLabel(result: result)
                        }

                        if appModel.isPolishingContext {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Button {
                            Task {
                                await appModel.polishUserContext()
                            }
                        } label: {
                            Label("Polish with AI", systemImage: "wand.and.stars")
                        }
                        .disabled(!appModel.canPolishUserContext)
                        .help("Use the active AI provider to refine your description and suggest missing details")
                    }

                    if !appModel.isAIConfigured {
                        Text("Configure Apple Intelligence or finish setting up the selected external provider in the AI Provider tab to use the polish feature.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            } header: {
                Text("About Me")
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }
}

private struct TimeTrackerCredentialSheet: View {
    let provider: TimeTrackerProvider
    @Binding var credentialText: String
    let onCancel: () -> Void
    let onConnect: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(provider.displayName) {
                    SecureField(provider.credentialLabel, text: $credentialText)
                }

                Section("Where to find it") {
                    Text(provider.connectInstructions)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Connect \(provider.displayName)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(provider.dialogButtonTitle) {
                        onConnect()
                    }
                    .disabled(credentialText.trimmed.isEmpty)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 240)
    }
}

private struct ExportRangeSheet: View {
    @Binding var format: AppStorageExportFormat
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onCancel: () -> Void
    let onExport: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Output Format") {
                    Picker("Format", selection: $format) {
                        ForEach(AppStorageExportFormat.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                }

                Section("Date Range") {
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    DatePicker("End", selection: $endDate, displayedComponents: .date)
                }

                Section {
                    Text("The export file is written as JSON using the standard system export panel.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Export Data")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Choose Location") {
                        onExport()
                    }
                }
            }
        }
        .frame(minWidth: 360, minHeight: 220)
    }
}

#if DEBUG
@MainActor
private func makeSettingsPreviewModel() -> PlannerAppModel {
    let persistenceController = try! PlannerPersistenceController.inMemory()
    let preferencesStore = PreferencesStore(userDefaults: UserDefaults(suiteName: "SettingsViewPreview")!)
    preferencesStore.selectedLLMProvider = .gemini
    preferencesStore.isAppleIntelligenceEnabled = true
    preferencesStore.userContext = "I usually work from 9 to 5, with a lunch break around noon."

    let model = PlannerAppModel(
        preferencesStore: preferencesStore,
        syncRepository: persistenceController.repository,
        storageSyncMode: persistenceController.syncMode,
        keychainStore: SettingsPreviewKeychainStore(
            values: [
                .geminiAPIKey: "demo-key",
                .togglAPIToken: "demo-token",
                .clockifyAPIToken: "clockify-demo-token",
                .harvestAccessToken: "harvest-demo-token"
            ]
        ),
        llmRouter: LLMServiceRouter(
            appleFoundationService: SettingsPreviewAppleService(),
            geminiService: SettingsPreviewExternalLLMService(),
            claudeService: SettingsPreviewExternalLLMService(),
            openAIService: SettingsPreviewExternalLLMService()
        ),
        togglService: SettingsPreviewTogglService(),
        clockifyService: SettingsPreviewClockifyService(),
        harvestService: SettingsPreviewHarvestService()
    )
    model.selectedSettingsTab = .timeTracker
    _ = model.refreshAppleIntelligenceAvailability()
    return model
}

private final class SettingsPreviewKeychainStore: KeychainStoring {
    private var values: [KeychainKey: String]

    init(values: [KeychainKey: String]) {
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

private struct SettingsPreviewAppleService: LLMServicing, AppleIntelligenceAvailabilityChecking {
    func checkAppleIntelligenceAvailability() throws {}

    func extractTimeEntries(
        apiKey: String,
        model: String,
        note: DailyNoteInput,
        timeZone: TimeZone,
        extractionContext: LLMExtractionContext
    ) async throws -> GeminiExtractionResponse {
        GeminiExtractionResponse(entries: [], assumptions: [], summary: nil)
    }

    func testConnection(apiKey: String, model: String) async throws -> String {
        "ok"
    }

    func polishUserContext(apiKey: String, model: String, rawText: String) async throws -> String {
        rawText
    }
}

private struct SettingsPreviewExternalLLMService: LLMServicing {
    func extractTimeEntries(
        apiKey: String,
        model: String,
        note: DailyNoteInput,
        timeZone: TimeZone,
        extractionContext: LLMExtractionContext
    ) async throws -> GeminiExtractionResponse {
        GeminiExtractionResponse(entries: [], assumptions: [], summary: nil)
    }

    func testConnection(apiKey: String, model: String) async throws -> String {
        "ok"
    }

    func polishUserContext(apiKey: String, model: String, rawText: String) async throws -> String {
        rawText
    }
}

private struct SettingsPreviewTogglService: TogglServicing {
    func fetchCurrentUser(apiToken: String) async throws -> TogglCurrentUserDTO {
        TogglCurrentUserDTO(id: 1, fullname: "Preview User", email: "preview@example.com")
    }

    func fetchWorkspaces(apiToken: String) async throws -> [WorkspaceSummary] {
        [WorkspaceSummary(id: 1, name: "Preview Workspace")]
    }

    func fetchProjects(apiToken: String, workspaceID: Int) async throws -> [ProjectSummary] {
        []
    }

    func createTimeEntries(
        _ submissions: [StoredTimeEntryRecord.TogglSubmission],
        apiToken: String
    ) async throws -> [TogglCreatedTimeEntryDTO] {
        []
    }
}

private struct SettingsPreviewClockifyService: ClockifyServicing {
    func fetchCurrentUser(apiKey: String) async throws -> ClockifyCurrentUserDTO {
        ClockifyCurrentUserDTO(
            id: "preview-user",
            name: "Preview Clockify User",
            email: "preview-clockify@example.com",
            activeWorkspace: "workspace-1",
            defaultWorkspace: "workspace-1"
        )
    }

    func fetchWorkspaces(apiKey: String) async throws -> [ClockifyWorkspaceSummary] {
        [ClockifyWorkspaceSummary(id: "workspace-1", name: "Design Studio")]
    }

    func fetchProjects(apiKey: String, workspaceID: String) async throws -> [ClockifyProjectSummary] {
        [ClockifyProjectSummary(id: "project-1", name: "Website Refresh", workspaceId: workspaceID)]
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

private struct SettingsPreviewHarvestService: HarvestServicing {
    func fetchAccounts(accessToken: String) async throws -> [HarvestAccountSummary] {
        [HarvestAccountSummary(id: 11, name: "Preview Company")]
    }

    func fetchCurrentUser(accessToken: String, accountID: Int) async throws -> HarvestCurrentUserDTO {
        HarvestCurrentUserDTO(
            id: 1,
            firstName: "Preview",
            lastName: "Harvest User",
            email: "preview-harvest@example.com"
        )
    }

    func fetchProjectAssignments(accessToken: String, accountID: Int) async throws -> [HarvestProjectSummary] {
        [
            HarvestProjectSummary(
                id: 21,
                name: "Client Delivery",
                taskAssignments: [
                    HarvestTaskSummary(id: 31, name: "Implementation"),
                    HarvestTaskSummary(id: 32, name: "Support")
                ]
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

#Preview("Settings") {
    SettingsView()
        .environmentObject(makeSettingsPreviewModel())
}
#endif
