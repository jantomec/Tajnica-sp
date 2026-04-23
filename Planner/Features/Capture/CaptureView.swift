import SwiftUI

struct CaptureView: View {
    @EnvironmentObject private var appModel: PlannerAppModel

    private var aiSettingsActionView: AnyView {
        #if os(macOS)
        return AnyView(
            SettingsLink {
                Text("Open AI Settings")
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    appModel.selectedSettingsTab = .aiProvider
                }
            )
        )
        #else
        return AnyView(
            Button("Open AI Settings") {
                appModel.selectedSettingsTab = .aiProvider
                appModel.selectedTab = .settings
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        )
        #endif
    }

    private var clearDraftButton: some View {
        Button(role: .destructive) {
            appModel.clearDraft()
        } label: {
            Label("Clear Draft", systemImage: "trash")
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
    }

    private var processButton: some View {
        Button {
            Task {
                await appModel.processNote()
            }
        } label: {
            Label(
                appModel.draft.candidateEntries.isEmpty ? "Process" : "Regenerate",
                systemImage: appModel.draft.candidateEntries.isEmpty ? "wand.and.stars" : "arrow.clockwise"
            )
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .disabled(!appModel.canProcess)
    }

    @ViewBuilder
    private var processingIndicator: some View {
        if appModel.isProcessing {
            ProgressView()
                .controlSize(.small)
        }
    }

    private var actionSection: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                clearDraftButton

                Spacer(minLength: 12)

                processingIndicator
                processButton
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    clearDraftButton

                    Spacer(minLength: 12)

                    processingIndicator
                }

                HStack {
                    Spacer(minLength: 0)
                    processButton
                }
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let status = appModel.captureStatusMessage {
                    StatusBanner(text: status, style: .success)
                }

                if let error = appModel.captureErrorMessage {
                    StatusBanner(text: error, style: .error)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("What did you do today?")
                        .font(.title2.weight(.semibold))

                    Text("Paste or write your day in any language. \(AppConfiguration.displayName) turns your note into candidate time entries using your selected AI engine.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }

                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                    Text(PlannerFormatters.dateString(appModel.draft.note.date))
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.secondary.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
                        )

                    ZStack(alignment: .topLeading) {
                        TextEditor(
                            text: Binding(
                                get: { appModel.draft.note.rawText },
                                set: { appModel.updateRawText($0) }
                            )
                        )
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 200)

                        if appModel.draft.note.rawText.isEmpty {
                            Text("Write your note here. Example: client call in the morning, lunch, bug fixing in the afternoon, admin at the end of the day.")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(12)
                }

                if !appModel.isAIConfigured {
                    StatusBanner(
                        text: "Your AI engine is not configured. Enable Apple Intelligence or finish setting up the selected external provider before processing notes.",
                        style: .warning,
                        actionView: aiSettingsActionView
                    )
                } else if !appModel.draft.candidateEntries.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Text("\(appModel.draft.candidateEntries.count) candidate entries saved. Regenerating will replace them.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                actionSection
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(24)
            .frame(maxWidth: 780, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle("Capture")
        .onAppear {
            appModel.refreshNoteDateForPresentation()
        }
        .confirmationDialog(
            "Replace the current review entries?",
            isPresented: $appModel.shouldConfirmRegeneration,
            titleVisibility: .visible
        ) {
            Button("Regenerate", role: .destructive) {
                Task {
                    await appModel.processNote(replacingExistingEntries: true)
                }
            }
        } message: {
            Text("Manual edits in the review draft will be replaced.")
        }
    }
}

#if DEBUG
@MainActor
private func makeCapturePreviewModel() -> PlannerAppModel {
    let persistenceController = try! PlannerPersistenceController.inMemory()
    let suiteName = "CaptureViewPreview"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    userDefaults.removePersistentDomain(forName: suiteName)

    let preferencesStore = PreferencesStore(userDefaults: userDefaults)
    preferencesStore.selectedLLMProvider = .openAI
    preferencesStore.setLLMModel("gpt-4o", for: .openAI)
    preferencesStore.userContext = "I usually capture a rough timeline first, then clean up candidate entries before submission."

    let previewTimeZone = TimeZone(identifier: "Europe/Ljubljana") ?? .autoupdatingCurrent
    try! persistenceController.repository.saveDraft(capturePreviewDraft(in: previewTimeZone))

    let model = PlannerAppModel(
        preferencesStore: preferencesStore,
        syncRepository: persistenceController.repository,
        storageSyncMode: persistenceController.syncMode,
        keychainStore: CapturePreviewKeychainStore(),
        llmRouter: LLMServiceRouter(
            appleFoundationService: CapturePreviewLLMService(),
            geminiService: CapturePreviewLLMService(),
            claudeService: CapturePreviewLLMService(),
            openAIService: CapturePreviewLLMService()
        ),
        togglService: CapturePreviewTogglService(),
        clockifyService: CapturePreviewClockifyService(),
        harvestService: CapturePreviewHarvestService(),
        timeZone: previewTimeZone
    )
    model.selectedTab = .capture
    return model
}

private func capturePreviewDraft(in timeZone: TimeZone) -> PlannerDraft {
    let day = capturePreviewDay(in: timeZone)

    return PlannerDraft(
        note: DailyNoteInput(
            date: day,
            rawText: """
            08:45 inbox cleanup and planning
            09:30 client workshop prep
            11:00 feature work on CaptureView previews
            15:00 bug fixes and follow-up notes
            """
        ),
        candidateEntries: [
            CandidateTimeEntry(
                date: day,
                start: try! LocalTimeParser.parse("08:45", on: day, in: timeZone),
                stop: try! LocalTimeParser.parse("10:15", on: day, in: timeZone),
                description: "Planning and workshop preparation",
                tags: ["planning", "client"],
                source: .user
            ),
            CandidateTimeEntry(
                date: day,
                start: try! LocalTimeParser.parse("11:00", on: day, in: timeZone),
                stop: try! LocalTimeParser.parse("16:00", on: day, in: timeZone),
                description: "CaptureView preview work and cleanup",
                tags: ["swiftui", "preview"],
                source: .gemini
            )
        ],
        assumptions: [
            "Grouped short admin tasks into the surrounding work blocks."
        ],
        summary: "Two candidate entries are already saved for this note.",
        lastProcessedAt: .now
    )
}

private func capturePreviewDay(in timeZone: TimeZone) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar.date(from: DateComponents(
        timeZone: timeZone,
        year: 2026,
        month: 4,
        day: 16
    ))!
}

private final class CapturePreviewKeychainStore: KeychainStoring {
    func string(for key: KeychainKey) -> String? {
        switch key {
        case .openAIAPIKey:
            "preview-openai-key"
        default:
            nil
        }
    }

    func set(_ value: String, for key: KeychainKey) {}
    func removeValue(for key: KeychainKey) {}
}

private struct CapturePreviewLLMService: LLMServicing, AppleIntelligenceAvailabilityChecking {
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

private struct CapturePreviewTogglService: TogglServicing {
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

private struct CapturePreviewClockifyService: ClockifyServicing {
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

private struct CapturePreviewHarvestService: HarvestServicing {
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

#Preview("Capture - Desktop", traits: .fixedLayout(width: 1100, height: 780)) {
    NavigationStack {
        CaptureView()
    }
    .environmentObject(makeCapturePreviewModel())
}

#if os(iOS)
#Preview("Capture - iPhone", traits: .fixedLayout(width: 393, height: 852)) {
    NavigationStack {
        CaptureView()
    }
    .environment(\.horizontalSizeClass, .compact)
    .environment(\.verticalSizeClass, .regular)
    .environmentObject(makeCapturePreviewModel())
}

#Preview("Capture - iPad", traits: .fixedLayout(width: 1024, height: 1366)) {
    NavigationStack {
        CaptureView()
    }
    .environment(\.horizontalSizeClass, .regular)
    .environment(\.verticalSizeClass, .regular)
    .environmentObject(makeCapturePreviewModel())
}
#endif
#endif
