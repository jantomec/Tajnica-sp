import SwiftUI

struct DiaryView: View {
    @EnvironmentObject private var appModel: PlannerAppModel
    @State private var selectedPrompt: DiaryPromptRecord?

    var body: some View {
        GeometryReader { geometry in
            if appModel.diaryPromptHistory.isEmpty {
                ContentUnavailableView(
                    "No Prompts Yet",
                    systemImage: "book.closed",
                    description: Text("Processed prompts will appear here once you send them.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(appModel.diaryFeedItems) { item in
                            switch item {
                            case let .dateSeparator(day):
                                DiaryDateSeparatorView(day: day)
                            case let .prompt(record):
                                DiaryMessageBubble(
                                    record: record,
                                    bubbleWidth: bubbleWidth(for: geometry.size.width),
                                    onOpen: {
                                        selectedPrompt = record
                                    }
                                )
                            }
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 820, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle("Diary")
        .sheet(item: $selectedPrompt) { record in
            DiaryPromptTimelineSheet(record: record)
                .environmentObject(appModel)
        }
    }

    private func bubbleWidth(for availableWidth: CGFloat) -> CGFloat {
        min(max(availableWidth - 48, 240), 560)
    }
}

private struct DiaryPromptTimelineSheet: View {
    @EnvironmentObject private var appModel: PlannerAppModel
    @Environment(\.dismiss) private var dismiss

    let record: DiaryPromptRecord

    @State private var selectedEntryID: UUID?

    private var submittedEntries: [StoredTimeEntryRecord] {
        appModel.latestStoredEntries(for: record.id)
    }

    private var draftEntries: [CandidateTimeEntry] {
        appModel.activeDraftEntries(for: record.id)
    }

    private var timelineEntries: [CandidateTimeEntry] {
        if !submittedEntries.isEmpty {
            return submittedEntries.map(\.displayCandidateEntry)
        }

        return draftEntries
    }

    private var isShowingSubmittedEntries: Bool {
        !submittedEntries.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prompt")
                            .font(.headline)
                        Text(record.rawText)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    StatusBanner(
                        text: isShowingSubmittedEntries
                            ? "Showing the latest saved submission generated from this prompt."
                            : "No submitted entries are saved for this prompt yet. Showing the current draft entries when available.",
                        style: isShowingSubmittedEntries ? .info : .warning
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Timeline")
                            .font(.headline)

                        if timelineEntries.isEmpty {
                            ContentUnavailableView(
                                "No Entries Saved",
                                systemImage: "clock.badge.xmark",
                                description: Text("There are no local entries associated with this prompt yet.")
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .background(
                                Color.secondary.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                        } else {
                            DayTimelineView(
                                entries: timelineEntries,
                                selectedEntryID: selectedEntryID,
                                onSelect: { entry in
                                    selectedEntryID = entry.id
                                }
                            )
                            .padding(12)
                            .background(
                                Color.secondary.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                        }
                    }

                    if !timelineEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Entries")
                                .font(.headline)

                            ForEach(timelineEntries) { entry in
                                diaryEntryCard(entry)
                            }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: 960, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .navigationTitle(PlannerFormatters.dateString(record.day))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 560, minHeight: 520)
    }

    @ViewBuilder
    private func diaryEntryCard(_ entry: CandidateTimeEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
            }

            if let serviceSummary = serviceSummary(for: entry), !serviceSummary.isEmpty {
                Text(serviceSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !entry.tags.isEmpty {
                Text(entry.tags.map { "#\($0)" }.joined(separator: " "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(selectedEntryID == entry.id ? Color.accentColor.opacity(0.35) : .clear, lineWidth: 1)
        }
        .onTapGesture {
            selectedEntryID = entry.id
        }
    }

    private func serviceSummary(for entry: CandidateTimeEntry) -> String? {
        var segments = [String]()

        if let toggl = entry.togglTarget {
            let details = [toggl.workspaceName?.trimmed.nilIfBlank, toggl.projectName?.trimmed.nilIfBlank]
                .compactMap { $0 }
                .joined(separator: " / ")
            if !details.isEmpty {
                segments.append("Toggl: \(details)")
            }
        }

        if let clockify = entry.clockifyTarget {
            let details = [clockify.workspaceName?.trimmed.nilIfBlank, clockify.projectName?.trimmed.nilIfBlank]
                .compactMap { $0 }
                .joined(separator: " / ")
            if !details.isEmpty {
                segments.append("Clockify: \(details)")
            }
        }

        if let harvest = entry.harvestTarget {
            let details = [
                harvest.accountName?.trimmed.nilIfBlank,
                harvest.projectName?.trimmed.nilIfBlank,
                harvest.taskName?.trimmed.nilIfBlank
            ]
            .compactMap { $0 }
            .joined(separator: " / ")
            if !details.isEmpty {
                segments.append("Harvest: \(details)")
            }
        }

        return segments.isEmpty ? nil : segments.joined(separator: "  |  ")
    }
}

private extension StoredTimeEntryRecord {
    var displayCandidateEntry: CandidateTimeEntry {
        CandidateTimeEntry(
            id: id,
            date: baseEntry.date,
            start: baseEntry.start,
            stop: baseEntry.stop,
            description: baseEntry.description,
            togglTarget: toggl.map {
                CandidateTimeEntry.TogglTarget(
                    workspaceName: $0.workspaceName,
                    workspaceId: $0.workspaceID,
                    projectName: $0.projectName,
                    projectId: $0.request.projectId
                )
            },
            clockifyTarget: clockify.map {
                CandidateTimeEntry.ClockifyTarget(
                    workspaceName: $0.workspaceName,
                    workspaceId: $0.workspaceID,
                    projectName: $0.projectName,
                    projectId: $0.request.projectId
                )
            },
            harvestTarget: harvest.map {
                CandidateTimeEntry.HarvestTarget(
                    accountName: $0.accountName,
                    accountId: $0.accountID,
                    projectName: $0.projectName,
                    projectId: $0.projectID,
                    taskName: $0.taskName,
                    taskId: $0.taskID
                )
            },
            tags: baseEntry.tags,
            billable: baseEntry.billable,
            source: baseEntry.source
        )
    }
}

#if DEBUG
@MainActor
private func makeDiaryPreviewModel() -> PlannerAppModel {
    let persistenceController = try! PlannerPersistenceController.inMemory()
    let suiteName = "DiaryViewPreview"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    userDefaults.removePersistentDomain(forName: suiteName)

    let preferencesStore = PreferencesStore(userDefaults: userDefaults)
    preferencesStore.selectedLLMProvider = .openAI
    preferencesStore.setLLMModel("gpt-4o", for: .openAI)
    preferencesStore.userContext = "I usually capture rough notes, then review and submit cleaned-up time entries later."

    let previewTimeZone = TimeZone(identifier: "Europe/Ljubljana") ?? .autoupdatingCurrent
    let previewRecords = makeDiaryPreviewRecords(in: previewTimeZone)
    let olderPrompt = previewRecords[0]
    let currentPrompt = previewRecords[1]
    let latestPrompt = previewRecords[2]

    try! persistenceController.repository.appendDiaryPrompt(olderPrompt)
    try! persistenceController.repository.appendDiaryPrompt(currentPrompt)
    try! persistenceController.repository.appendDiaryPrompt(latestPrompt)
    try! persistenceController.repository.upsertStoredEntries(
        diaryPreviewStoredEntries(for: olderPrompt, in: previewTimeZone)
    )
    try! persistenceController.repository.saveDraft(
        diaryPreviewDraft(for: latestPrompt, in: previewTimeZone)
    )

    let model = PlannerAppModel(
        preferencesStore: preferencesStore,
        syncRepository: persistenceController.repository,
        storageSyncMode: persistenceController.syncMode,
        keychainStore: DiaryPreviewKeychainStore(),
        llmRouter: LLMServiceRouter(
            appleFoundationService: DiaryPreviewLLMService(),
            geminiService: DiaryPreviewLLMService(),
            claudeService: DiaryPreviewLLMService(),
            openAIService: DiaryPreviewLLMService()
        ),
        togglService: DiaryPreviewTogglService(),
        clockifyService: DiaryPreviewClockifyService(),
        harvestService: DiaryPreviewHarvestService(),
        timeZone: previewTimeZone
    )
    model.selectedTab = .diary
    return model
}

private func makeDiaryPreviewRecords(in timeZone: TimeZone) -> [DiaryPromptRecord] {
    let firstDay = diaryPreviewDay(year: 2026, month: 4, day: 15, in: timeZone)
    let secondDay = diaryPreviewDay(year: 2026, month: 4, day: 16, in: timeZone)

    return [
        DiaryPromptRecord(
            day: firstDay,
            rawText: """
            Yesterday:
            09:00 client standup
            10:00-12:00 worked on export fixes
            14:00 triaged follow-up bugs and shipped a small patch
            """,
            createdAt: diaryPreviewTimestamp(year: 2026, month: 4, day: 15, hour: 18, minute: 5, in: timeZone)
        ),
        DiaryPromptRecord(
            day: secondDay,
            rawText: "Morning planning, review polish, and a couple of quick support replies before lunch.",
            createdAt: diaryPreviewTimestamp(year: 2026, month: 4, day: 16, hour: 10, minute: 5, in: timeZone)
        ),
        DiaryPromptRecord(
            day: secondDay,
            rawText: """
            Afternoon notes:
            13:30 deep focus on the diary feed layout
            14:15 adjusted the bubble width behavior
            15:00 validated timeline interactions
            15:45 checked the compact preview output
            16:30 wrapped preview fixes and tagged cleanup
            """,
            createdAt: diaryPreviewTimestamp(year: 2026, month: 4, day: 16, hour: 17, minute: 10, in: timeZone)
        )
    ]
}

private func diaryPreviewDraft(for record: DiaryPromptRecord, in timeZone: TimeZone) -> PlannerDraft {
    PlannerDraft(
        note: DailyNoteInput(date: record.day, rawText: record.rawText),
        candidateEntries: [
            CandidateTimeEntry(
                date: record.day,
                start: try! LocalTimeParser.parse("13:30", on: record.day, in: timeZone),
                stop: try! LocalTimeParser.parse("15:00", on: record.day, in: timeZone),
                description: "Deep focus on diary feed layout",
                togglTarget: CandidateTimeEntry.TogglTarget(
                    workspaceName: "Client Work",
                    workspaceId: 101,
                    projectName: "Diary UX",
                    projectId: 1_201
                ),
                tags: ["swiftui", "diary"],
                source: .user
            ),
            CandidateTimeEntry(
                date: record.day,
                start: try! LocalTimeParser.parse("15:00", on: record.day, in: timeZone),
                stop: try! LocalTimeParser.parse("16:30", on: record.day, in: timeZone),
                description: "Validate timeline interactions and polish previews",
                clockifyTarget: CandidateTimeEntry.ClockifyTarget(
                    workspaceName: "Internal Workspace",
                    workspaceId: "clockify-internal",
                    projectName: "Preview Cleanup",
                    projectId: "clockify-preview"
                ),
                harvestTarget: CandidateTimeEntry.HarvestTarget(
                    accountName: "Acme Studio",
                    accountId: 201,
                    projectName: "Planner Product",
                    projectId: 2_001,
                    taskName: "Feature Development",
                    taskId: 3_001
                ),
                tags: ["timeline", "preview"],
                billable: true,
                source: .gemini
            )
        ],
        assumptions: [
            "Combined short support replies into the surrounding work blocks."
        ],
        summary: "Two candidate entries are ready for the latest diary prompt.",
        lastProcessedAt: .now,
        sourceDiaryPromptID: record.id
    )
}

private func diaryPreviewStoredEntries(
    for record: DiaryPromptRecord,
    in timeZone: TimeZone
) -> [StoredTimeEntryRecord] {
    [
        StoredTimeEntryRecord(
            entry: CandidateTimeEntry(
                date: record.day,
                start: try! LocalTimeParser.parse("09:00", on: record.day, in: timeZone),
                stop: try! LocalTimeParser.parse("10:00", on: record.day, in: timeZone),
                description: "Client standup and planning",
                togglTarget: CandidateTimeEntry.TogglTarget(
                    workspaceName: "Client Work",
                    workspaceId: 101,
                    projectName: "Planner macOS",
                    projectId: 1_001
                ),
                tags: ["team", "planning"],
                billable: true,
                source: .user
            ),
            submittedAt: diaryPreviewTimestamp(year: 2026, month: 4, day: 15, hour: 18, minute: 5, in: timeZone),
            diaryPromptRecordID: record.id
        ),
        StoredTimeEntryRecord(
            entry: CandidateTimeEntry(
                date: record.day,
                start: try! LocalTimeParser.parse("10:00", on: record.day, in: timeZone),
                stop: try! LocalTimeParser.parse("12:00", on: record.day, in: timeZone),
                description: "Export fixes and regression pass",
                clockifyTarget: CandidateTimeEntry.ClockifyTarget(
                    workspaceName: "Client Workspace",
                    workspaceId: "clockify-client",
                    projectName: "Export Stabilization",
                    projectId: "clockify-export"
                ),
                tags: ["export", "qa"],
                billable: true,
                source: .gemini
            ),
            submittedAt: diaryPreviewTimestamp(year: 2026, month: 4, day: 15, hour: 18, minute: 5, in: timeZone),
            diaryPromptRecordID: record.id
        )
    ]
}

private func diaryPreviewDay(year: Int, month: Int, day: Int, in timeZone: TimeZone) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar.date(from: DateComponents(
        timeZone: timeZone,
        year: year,
        month: month,
        day: day
    ))!
}

private func diaryPreviewTimestamp(
    year: Int,
    month: Int,
    day: Int,
    hour: Int,
    minute: Int,
    in timeZone: TimeZone
) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar.date(from: DateComponents(
        timeZone: timeZone,
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute
    ))!
}

private final class DiaryPreviewKeychainStore: KeychainStoring {
    func string(for key: KeychainKey) -> String? { nil }
    func set(_ value: String, for key: KeychainKey) {}
    func removeValue(for key: KeychainKey) {}
}

private struct DiaryPreviewLLMService: LLMServicing, AppleIntelligenceAvailabilityChecking {
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

private struct DiaryPreviewTogglService: TogglServicing {
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

private struct DiaryPreviewClockifyService: ClockifyServicing {
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

private struct DiaryPreviewHarvestService: HarvestServicing {
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

#Preview("Diary - Desktop", traits: .fixedLayout(width: 1100, height: 780)) {
    NavigationStack {
        DiaryView()
    }
    .environmentObject(makeDiaryPreviewModel())
}

#if os(iOS)
#Preview("Diary - iPhone", traits: .fixedLayout(width: 393, height: 852)) {
    NavigationStack {
        DiaryView()
    }
    .environmentObject(makeDiaryPreviewModel())
}
#endif
#endif
