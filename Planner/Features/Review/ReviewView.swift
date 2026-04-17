import SwiftUI

struct ReviewView: View {
    @EnvironmentObject private var appModel: PlannerAppModel
    @State private var editingEntry: CandidateTimeEntry?
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var useCompactEditor: Bool { horizontalSizeClass == .compact }
    #else
    private var useCompactEditor: Bool { false }
    #endif
    private let preferredTimelineEntryWidth: CGFloat = 220
    private let preferredTimelineLeadingInset: CGFloat = 68
    private let timelineCardHorizontalPadding: CGFloat = 24
    private let reviewHorizontalPadding: CGFloat = 24

    private var preferredTimelineWidth: CGFloat {
        preferredTimelineEntryWidth + preferredTimelineLeadingInset + timelineCardHorizontalPadding
    }

    private var timeTrackerSettingsActionView: AnyView {
        #if os(macOS)
        return AnyView(
            SettingsLink {
                Text("Open Time Tracker Settings")
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    appModel.selectedSettingsTab = .timeTracker
                }
            )
        )
        #else
        return AnyView(
            Button("Open Time Tracker Settings") {
                appModel.selectedSettingsTab = .timeTracker
                appModel.selectedTab = .settings
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        )
        #endif
    }

    /// Summarise the date(s) covered by candidate entries.
    private var entryDateSummary: String {
        let dates = Set(appModel.draft.candidateEntries.map {
            PlannerFormatters.dateString($0.date)
        })
        if dates.isEmpty {
            return PlannerFormatters.dateString(appModel.draft.note.date)
        }
        return dates.sorted().joined(separator: " / ")
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                let contentWidth = min(geometry.size.width, 1100) - (reviewHorizontalPadding * 2)
                let isWide = contentWidth >= preferredTimelineWidth * 2
                #if os(iOS)
                let shouldUseFullWidthTimeline = !isWide
                    && horizontalSizeClass == .compact
                    && geometry.size.height > geometry.size.width
                #else
                let shouldUseFullWidthTimeline = false
                #endif

                Group {
                    if isWide {
                        HStack(alignment: .top, spacing: 24) {
                            timelineSection
                                .frame(width: preferredTimelineWidth, alignment: .leading)

                            entriesSection
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 24) {
                            timelineSection
                                .frame(
                                    maxWidth: shouldUseFullWidthTimeline ? .infinity : preferredTimelineWidth,
                                    alignment: .leading
                                )
                            entriesSection
                        }
                    }
                }
                .padding(reviewHorizontalPadding)
                .frame(maxWidth: 1100, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("Review")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                addEntryButton
                submitButton
            }
        }
        .modifier(EntryEditorPresentation(
            editingEntry: $editingEntry,
            useCompactEditor: useCompactEditor,
            togglCatalogs: appModel.togglWorkspaceCatalogs,
            clockifyCatalogs: appModel.clockifyWorkspaceCatalogs,
            harvestCatalogs: appModel.harvestAccountCatalogs,
            enabledTrackers: appModel.enabledTimeTrackers,
            onSave: { appModel.saveEditedEntry($0) }
        ))
        .onAppear {
            openPendingReviewEntryIfNeeded()
        }
        .onChange(of: appModel.pendingReviewEntryID) { _, _ in
            openPendingReviewEntryIfNeeded()
        }
        .onChange(of: appModel.draft.candidateEntries) { _, _ in
            openPendingReviewEntryIfNeeded()
        }
    }

    private struct EntryEditorPresentation: ViewModifier {
        @Binding var editingEntry: CandidateTimeEntry?
        let useCompactEditor: Bool
        let togglCatalogs: [TogglWorkspaceCatalog]
        let clockifyCatalogs: [ClockifyWorkspaceCatalog]
        let harvestCatalogs: [HarvestAccountCatalog]
        let enabledTrackers: Set<TimeTrackerProvider>
        let onSave: (CandidateTimeEntry) -> Void

        func body(content: Content) -> some View {
            if useCompactEditor {
                content.sheet(item: $editingEntry) { entry in
                    EntryEditorView(
                        entry: entry,
                        togglCatalogs: togglCatalogs,
                        clockifyCatalogs: clockifyCatalogs,
                        harvestCatalogs: harvestCatalogs,
                        enabledTrackers: enabledTrackers
                    ) { updated in
                        onSave(updated)
                    }
                }
            } else {
                content.sheet(item: $editingEntry) { entry in
                    EntryEditorView(
                        entry: entry,
                        togglCatalogs: togglCatalogs,
                        clockifyCatalogs: clockifyCatalogs,
                        harvestCatalogs: harvestCatalogs,
                        enabledTrackers: enabledTrackers
                    ) { updated in
                        onSave(updated)
                    }
                }
            }
        }
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Day Timeline")
                .font(.headline)

            if appModel.draft.candidateEntries.isEmpty {
                ContentUnavailableView(
                    "No Entries Yet",
                    systemImage: "clock.badge.questionmark",
                    description: Text("Process a daily note first, or add an entry manually.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                DayTimelineView(
                    entries: appModel.draft.candidateEntries,
                    selectedEntryID: editingEntry?.id,
                    onSelect: { entry in
                        editingEntry = entry
                    }
                )
                .padding(12)
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection

            if let summary = appModel.draft.summary {
                StatusBanner(text: summary, style: .info)
            }

            if !appModel.draft.assumptions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Assumptions")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(appModel.draft.assumptions, id: \.self) { assumption in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "lightbulb")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text(assumption)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let status = appModel.reviewStatusMessage {
                StatusBanner(text: status, style: .success)
            }

            if let error = appModel.reviewErrorMessage {
                StatusBanner(text: error, style: .error)
            }

            if appModel.draft.candidateEntries.isEmpty {
                Text("No candidate entries for \(PlannerFormatters.dateString(appModel.draft.note.date)).")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appModel.draft.candidateEntries) { entry in
                    entryCard(entry)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerSummary

            if appModel.configuredExternalTimeTrackers.isEmpty {
                StatusBanner(
                    text: "These entries will be saved in \(appModel.appStorageDisplayName) only. Connect an external tracker in Settings if you also want to submit them elsewhere.",
                    style: .warning,
                    actionView: timeTrackerSettingsActionView
                )
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "externaldrive.connected.to.line.below")
                        .font(.caption)
                    Text(appModel.submissionDestinationSummary)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var headerSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entryDateSummary)
                .font(.title3.weight(.semibold))

            if appModel.totalErrorCount > 0 || appModel.totalWarningCount > 0 {
                HStack(spacing: 12) {
                    if appModel.totalErrorCount > 0 {
                        Label("\(appModel.totalErrorCount) errors", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                    if appModel.totalWarningCount > 0 {
                        Label("\(appModel.totalWarningCount) warnings", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.subheadline)
            }
        }
    }

    private var addEntryButton: some View {
        Button {
            appModel.addEntry()
        } label: {
            Image(systemName: "plus")
                .imageScale(.large)
        }
        .buttonBorderShape(.circle)
        .help("Add Entry")
        .accessibilityLabel("Add Entry")
    }

    private var submitButton: some View {
        Button {
            Task {
                await appModel.submitEntries()
            }
        } label: {
            Group {
                if appModel.isSubmitting {
                    ProgressView()
                        .controlSize(.large)
                } else {
                    Image(systemName: "paperplane.fill")
                        .imageScale(.large)
                }
            }
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .disabled(!appModel.canSubmit)
        .help(appModel.submissionDestinationSummary)
        .accessibilityLabel("Submit entries")
    }

    @ViewBuilder
    private func entryCard(_ entry: CandidateTimeEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.description.isBlank ? "Untitled Entry" : entry.description)
                        .font(.headline)

                    Text("\(PlannerFormatters.dateString(entry.date))  \(PlannerFormatters.timeRange(start: entry.start, stop: entry.stop))")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(PlannerFormatters.durationString(entry.duration))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                Button("Edit") {
                    editingEntry = entry
                }
                .controlSize(.small)

                Button("Duplicate") {
                    appModel.duplicateEntry(id: entry.id)
                }
                .controlSize(.small)

                Button("Delete", role: .destructive) {
                    appModel.deleteEntry(id: entry.id)
                }
                .controlSize(.small)
            }

            if !appModel.enabledTimeTrackers.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    serviceTargetRow(
                        title: TimeTrackerProvider.toggl.displayName,
                        value: togglTargetSummary(for: entry),
                        isVisible: appModel.enabledTimeTrackers.contains(.toggl)
                    )
                    serviceTargetRow(
                        title: TimeTrackerProvider.clockify.displayName,
                        value: clockifyTargetSummary(for: entry),
                        isVisible: appModel.enabledTimeTrackers.contains(.clockify)
                    )
                    serviceTargetRow(
                        title: TimeTrackerProvider.harvest.displayName,
                        value: harvestTargetSummary(for: entry),
                        isVisible: appModel.enabledTimeTrackers.contains(.harvest)
                    )
                }
            }

            if !entry.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(entry.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }

            if !entry.validationIssues.isEmpty {
                Divider()

                ForEach(entry.validationIssues) { issue in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: issue.severity == .error ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(issue.severity == .error ? Color.red : Color.orange)
                            .font(.caption)

                        Text(issue.message)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    entry.hasErrors ? Color.red.opacity(0.3) :
                    entry.hasWarnings ? Color.orange.opacity(0.3) :
                    Color.clear,
                    lineWidth: 1
                )
        )
    }

    @ViewBuilder
    private func serviceTargetRow(title: String, value: String?, isVisible: Bool) -> some View {
        if isVisible {
            HStack(alignment: .top, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 62, alignment: .leading)

                Text(value ?? "Needs selection")
                    .font(.subheadline)
                    .foregroundStyle(value == nil ? .orange : .secondary)
            }
        }
    }

    private func togglTargetSummary(for entry: CandidateTimeEntry) -> String? {
        let parts = [
            entry.togglTarget?.workspaceName?.trimmed.nilIfBlank,
            entry.togglTarget?.projectName?.trimmed.nilIfBlank
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " / ")
    }

    private func clockifyTargetSummary(for entry: CandidateTimeEntry) -> String? {
        let parts = [
            entry.clockifyTarget?.workspaceName?.trimmed.nilIfBlank,
            entry.clockifyTarget?.projectName?.trimmed.nilIfBlank
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " / ")
    }

    private func harvestTargetSummary(for entry: CandidateTimeEntry) -> String? {
        let parts = [
            entry.harvestTarget?.accountName?.trimmed.nilIfBlank,
            entry.harvestTarget?.projectName?.trimmed.nilIfBlank,
            entry.harvestTarget?.taskName?.trimmed.nilIfBlank
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " / ")
    }

    private func openPendingReviewEntryIfNeeded() {
        guard let entry = appModel.consumePendingReviewEntryIfAvailable() else { return }
        editingEntry = entry
    }
}

#if DEBUG
@MainActor
private func makeReviewPreviewModel() -> PlannerAppModel {
    let persistenceController = try! PlannerPersistenceController.inMemory()
    let suiteName = "ReviewViewPreview"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    userDefaults.removePersistentDomain(forName: suiteName)

    let preferencesStore = PreferencesStore(userDefaults: userDefaults)
    preferencesStore.selectedLLMProvider = .openAI
    preferencesStore.setLLMModel("gpt-4o", for: .openAI)
    preferencesStore.userContext = "I usually split my day between product work, coordination, and ad-hoc support."

    let previewTimeZone = TimeZone(identifier: "Europe/Ljubljana") ?? .autoupdatingCurrent
    try! persistenceController.repository.saveDraft(reviewPreviewDraft(in: previewTimeZone))

    let model = PlannerAppModel(
        preferencesStore: preferencesStore,
        syncRepository: persistenceController.repository,
        storageSyncMode: persistenceController.syncMode,
        keychainStore: ReviewPreviewKeychainStore(),
        llmRouter: LLMServiceRouter(
            appleFoundationService: ReviewPreviewLLMService(),
            geminiService: ReviewPreviewLLMService(),
            claudeService: ReviewPreviewLLMService(),
            openAIService: ReviewPreviewLLMService()
        ),
        togglService: ReviewPreviewTogglService(),
        clockifyService: ReviewPreviewClockifyService(),
        harvestService: ReviewPreviewHarvestService(),
        timeZone: previewTimeZone
    )
    model.selectedTab = .review
    model.reviewStatusMessage = "Previewing three candidate entries before submission."
    return model
}

private func reviewPreviewDraft(in timeZone: TimeZone) -> PlannerDraft {
    let day = reviewPreviewDay(in: timeZone)

    return PlannerDraft(
        note: DailyNoteInput(
            date: day,
            rawText: """
            09:00 standup and ticket triage
            10:30 worked on ReviewView layout
            15:00 deep work on export polish and sync follow-up
            """
        ),
        candidateEntries: [
            CandidateTimeEntry(
                date: day,
                start: try! LocalTimeParser.parse("09:00", on: day, in: timeZone),
                stop: try! LocalTimeParser.parse("10:15", on: day, in: timeZone),
                description: "Standup, triage, and planning",
                tags: ["team", "planning"],
                source: .gemini
            ),
            CandidateTimeEntry(
                date: day,
                start: try! LocalTimeParser.parse("10:30", on: day, in: timeZone),
                stop: try! LocalTimeParser.parse("12:00", on: day, in: timeZone),
                description: "Build ReviewView timeline layout",
                tags: ["swiftui", "review"],
                source: .user
            ),
            CandidateTimeEntry(
                date: day,
                start: try! LocalTimeParser.parse("15:00", on: day, in: timeZone),
                stop: try! LocalTimeParser.parse("20:00", on: day, in: timeZone),
                description: "Deep work on persistence and export flow",
                tags: ["sync", "export"],
                source: .gemini
            )
        ],
        assumptions: [
            "Grouped quick Slack replies into the surrounding work blocks.",
            "Treated afternoon focus work as one continuous session."
        ],
        summary: "The note resolves into three candidate entries with one long-session warning and one large-gap warning.",
        lastProcessedAt: .now
    )
}

private func reviewPreviewDay(in timeZone: TimeZone) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar.date(from: DateComponents(
        timeZone: timeZone,
        year: 2026,
        month: 4,
        day: 16
    ))!
}

private final class ReviewPreviewKeychainStore: KeychainStoring {
    func string(for key: KeychainKey) -> String? { nil }
    func set(_ value: String, for key: KeychainKey) {}
    func removeValue(for key: KeychainKey) {}
}

private struct ReviewPreviewLLMService: LLMServicing, AppleIntelligenceAvailabilityChecking {
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

private struct ReviewPreviewTogglService: TogglServicing {
    func fetchCurrentUser(apiToken: String) async throws -> TogglCurrentUserDTO {
        TogglCurrentUserDTO(id: 1, fullname: "Preview User", email: "preview@example.com")
    }

    func fetchWorkspaces(apiToken: String) async throws -> [WorkspaceSummary] {
        []
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

private struct ReviewPreviewClockifyService: ClockifyServicing {
    func fetchCurrentUser(apiKey: String) async throws -> ClockifyCurrentUserDTO {
        ClockifyCurrentUserDTO(
            id: "preview-user",
            name: "Preview User",
            email: "preview@example.com",
            activeWorkspace: "preview-workspace",
            defaultWorkspace: "preview-workspace"
        )
    }

    func fetchWorkspaces(apiKey: String) async throws -> [ClockifyWorkspaceSummary] {
        []
    }

    func fetchProjects(apiKey: String, workspaceID: String) async throws -> [ClockifyProjectSummary] {
        []
    }

    func createTimeEntries(
        _ submissions: [StoredTimeEntryRecord.ClockifySubmission],
        apiKey: String
    ) async throws -> [ClockifyCreatedTimeEntryDTO] {
        []
    }
}

private struct ReviewPreviewHarvestService: HarvestServicing {
    func fetchAccounts(accessToken: String) async throws -> [HarvestAccountSummary] {
        []
    }

    func fetchCurrentUser(accessToken: String, accountID: Int) async throws -> HarvestCurrentUserDTO {
        HarvestCurrentUserDTO(
            id: 1,
            firstName: "Preview",
            lastName: "User",
            email: "preview@example.com"
        )
    }

    func fetchProjectAssignments(accessToken: String, accountID: Int) async throws -> [HarvestProjectSummary] {
        []
    }

    func createTimeEntries(
        _ submissions: [StoredTimeEntryRecord.HarvestSubmission],
        accessToken: String
    ) async throws -> [HarvestCreatedTimeEntryDTO] {
        []
    }
}

#Preview("Review") {
    NavigationStack {
        ReviewView()
    }
    .frame(width: 1100, height: 780)
    .environmentObject(makeReviewPreviewModel())
}
#endif
