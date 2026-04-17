import Foundation
import FoundationModels

struct AppleFoundationModelsService: LLMServicing, AppleIntelligenceAvailabilityChecking {
    private let systemModel: SystemLanguageModel
    private let availabilityProvider: @Sendable () -> SystemLanguageModel.Availability
    private let isSimulator: Bool

    init(systemModel: SystemLanguageModel = .default) {
        self.systemModel = systemModel
        self.availabilityProvider = { systemModel.availability }
        #if targetEnvironment(simulator)
        self.isSimulator = true
        #else
        self.isSimulator = false
        #endif
    }

    init(
        systemModel: SystemLanguageModel = .default,
        availabilityProvider: @escaping @Sendable () -> SystemLanguageModel.Availability,
        isSimulator: Bool = false
    ) {
        self.systemModel = systemModel
        self.availabilityProvider = availabilityProvider
        self.isSimulator = isSimulator
    }

    func extractTimeEntries(
        apiKey: String,
        model: String,
        note: DailyNoteInput,
        timeZone: TimeZone,
        extractionContext: LLMExtractionContext
    ) async throws -> GeminiExtractionResponse {
        try ensureModelIsAvailable()

        let session = LanguageModelSession(model: systemModel) {
            extractionInstructions
        }

        do {
            let response = try await session.respond(
                to: makeExtractionPrompt(
                    note: note,
                    timeZone: timeZone,
                    extractionContext: extractionContext
                ),
                generating: AppleFoundationExtractionPayload.self,
                options: GenerationOptions(
                    sampling: .greedy,
                    maximumResponseTokens: 2_048
                )
            )
            return response.content.asPlannerResponse()
        } catch {
            throw map(error)
        }
    }

    func testConnection(apiKey: String, model: String) async throws -> String {
        try ensureModelIsAvailable()

        let session = LanguageModelSession(model: systemModel)

        do {
            _ = try await session.respond(
                to: "Reply with the single word ok.",
                options: GenerationOptions(
                    sampling: .greedy,
                    maximumResponseTokens: 16
                )
            )
            return "ok"
        } catch {
            throw map(error)
        }
    }

    func polishUserContext(apiKey: String, model: String, rawText: String) async throws -> String {
        try ensureModelIsAvailable()

        let session = LanguageModelSession(model: systemModel) {
            polishInstructions
        }

        do {
            let response = try await session.respond(
                to: "Polish this user description for time-tracking context:\n\n\(rawText)",
                options: GenerationOptions(
                    sampling: .greedy,
                    maximumResponseTokens: 1_024
                )
            )
            return response.content.trimmed
        } catch {
            throw map(error)
        }
    }

    func checkAppleIntelligenceAvailability() throws {
        try ensureModelIsAvailable()
    }

    private var extractionInstructions: String {
        LLMExtractionPromptBuilder.systemInstruction
    }

    private var polishInstructions: String {
        """
        You help users describe themselves and their work patterns for a time-tracking app called \(AppConfiguration.displayName).
        The app feeds this description into an LLM to better predict and structure daily time entries.

        Your job:
        1. Take the user's raw text about themselves and polish it into a clear, structured description that will help an LLM make better time entry predictions.
        2. If important information is missing, append questions directly in the text prefixed with "Q: " so the user can answer them and run the polish again.

        Important details to capture if not already present:
        - Typical working hours, breaks, and time boundaries
        - Type of work such as engineering, design, management, consulting, or support
        - Common projects or clients
        - Recurring meetings or activities
        - Preferred time block lengths
        - Billable versus non-billable work patterns

        Keep the tone professional but friendly.
        Write in first person from the user's perspective.
        Return only the polished text, not JSON or markdown.
        """
    }

    private func makeExtractionPrompt(
        note: DailyNoteInput,
        timeZone: TimeZone,
        extractionContext: LLMExtractionContext
    ) -> String {
        LLMExtractionPromptBuilder.makeUserPrompt(
            selectedDate: note.date,
            timeZone: timeZone,
            note: note.rawText,
            context: extractionContext
        )
    }

    private func ensureModelIsAvailable() throws {
        switch availabilityProvider() {
        case .available:
            return
        case let .unavailable(reason):
            throw PlannerServiceError.emptyResponse(Self.unavailableMessage(for: reason))
        }
    }

    static var simulatorUnavailableMessage: String {
        "Apple Foundation Models is not available. Test on an Apple Intelligence-capable device, or switch to a cloud provider."
    }

    static func unavailableMessage(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "Apple Foundation Models is unavailable because this device is not eligible for Apple Intelligence. Use a supported Apple device or switch to a cloud provider."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is turned off on this device. Enable it in Apple Intelligence & Siri settings, then try again."
        case .modelNotReady:
            return "Apple Foundation Models is not ready yet. The on-device model is still preparing. Please try again later."
        @unknown default:
            return "Apple Foundation Models is not available on this device right now."
        }
    }

    private func map(_ error: Error) -> Error {
        if isSimulator {
            let nsError = error as NSError
            if nsError.domain.contains("FoundationModels") || nsError.localizedDescription.contains("FoundationModels") {
                return PlannerServiceError.emptyResponse(Self.simulatorUnavailableMessage)
            }
        }

        guard let generationError = error as? LanguageModelSession.GenerationError else {
            return error
        }

        switch generationError {
        case .exceededContextWindowSize(_):
            return PlannerServiceError.emptyResponse("The note is too large for the on-device model. Shorten it or switch to a cloud provider.")
        case .assetsUnavailable(_):
            return PlannerServiceError.emptyResponse("The Apple on-device model assets are unavailable right now. Try again after they finish downloading or preparing.")
        case .guardrailViolation(_):
            return PlannerServiceError.emptyResponse("Apple Foundation Models refused this request.")
        case .unsupportedGuide(_), .decodingFailure(_):
            return PlannerServiceError.decoding("Apple Foundation Models returned output that did not match \(AppConfiguration.displayName)'s expected schema.")
        case .unsupportedLanguageOrLocale(_):
            return PlannerServiceError.emptyResponse("Apple Foundation Models could not handle the current language or locale for this request. Try a cloud provider for broader language support.")
        case .rateLimited(_), .concurrentRequests(_):
            return PlannerServiceError.emptyResponse("Apple Foundation Models is busy right now. Try again in a moment.")
        case .refusal(_, _):
            return PlannerServiceError.emptyResponse("Apple Foundation Models refused this request.")
        @unknown default:
            return PlannerServiceError.emptyResponse("Apple Foundation Models failed to generate a usable response.")
        }
    }
}

private struct AppleFoundationExtractionPayload: Generable {
    let entries: [Entry]
    let assumptions: [String]
    let summary: String?

    static var generationSchema: GenerationSchema {
        GenerationSchema(
            type: Self.self,
            description: "Candidate time entries extracted from a daily work note.",
            properties: [
                .init(name: "entries", description: "Ordered candidate time entries.", type: [Entry].self),
                .init(name: "assumptions", description: "Short notes about inferred details.", type: [String].self),
                .init(name: "summary", description: "Optional short summary of the day.", type: String?.self)
            ]
        )
    }

    init(_ content: GeneratedContent) throws {
        entries = try content.value([Entry].self, forProperty: "entries")
        assumptions = try content.value([String].self, forProperty: "assumptions")
        summary = try content.value(String?.self, forProperty: "summary")
    }

    var generatedContent: GeneratedContent {
        GeneratedContent(
            kind: .structure(
                properties: [
                    "entries": GeneratedContent(entries),
                    "assumptions": GeneratedContent(assumptions),
                    "summary": summary.map { GeneratedContent($0) } ?? GeneratedContent(kind: .null)
                ],
                orderedKeys: ["entries", "assumptions", "summary"]
            )
        )
    }

    func asPlannerResponse() -> GeminiExtractionResponse {
        GeminiExtractionResponse(
            entries: entries.map(\.asPlannerEntry),
            assumptions: assumptions,
            summary: summary?.trimmed.nilIfBlank
        )
    }

    struct Entry: Generable {
        let dateLocal: String
        let startLocal: String
        let stopLocal: String
        let description: String
        let togglWorkspaceName: String?
        let togglProjectName: String?
        let clockifyWorkspaceName: String?
        let clockifyProjectName: String?
        let harvestAccountName: String?
        let harvestProjectName: String?
        let harvestTaskName: String?
        let tags: [String]
        let billable: Bool?

        static var generationSchema: GenerationSchema {
            GenerationSchema(
                type: Self.self,
                description: "A candidate time entry.",
                properties: [
                    .init(name: "date_local", description: "Local calendar date in YYYY-MM-DD format.", type: String.self),
                    .init(name: "start_local", description: "Start time in 24-hour HH:mm format.", type: String.self),
                    .init(name: "stop_local", description: "Stop time in 24-hour HH:mm format.", type: String.self),
                    .init(name: "description", description: "Concise time-entry description.", type: String.self),
                    .init(name: "toggl_workspace_name", description: "Exact Toggl workspace name when needed, otherwise null.", type: String?.self),
                    .init(name: "toggl_project_name", description: "Exact Toggl project name when clearly known, otherwise null.", type: String?.self),
                    .init(name: "clockify_workspace_name", description: "Exact Clockify workspace name when needed, otherwise null.", type: String?.self),
                    .init(name: "clockify_project_name", description: "Exact Clockify project name when clearly known, otherwise null.", type: String?.self),
                    .init(name: "harvest_account_name", description: "Exact Harvest account name when needed, otherwise null.", type: String?.self),
                    .init(name: "harvest_project_name", description: "Exact Harvest project name when clearly known, otherwise null.", type: String?.self),
                    .init(name: "harvest_task_name", description: "Exact Harvest task name when clearly known, otherwise null.", type: String?.self),
                    .init(name: "tags", description: "Optional short tags.", type: [String].self),
                    .init(name: "billable", description: "Whether the entry is billable when known, otherwise null.", type: Bool?.self)
                ]
            )
        }

        init(_ content: GeneratedContent) throws {
            dateLocal = try content.value(String.self, forProperty: "date_local")
            startLocal = try content.value(String.self, forProperty: "start_local")
            stopLocal = try content.value(String.self, forProperty: "stop_local")
            description = try content.value(String.self, forProperty: "description")
            togglWorkspaceName = try content.value(String?.self, forProperty: "toggl_workspace_name")
            togglProjectName = try content.value(String?.self, forProperty: "toggl_project_name")
            clockifyWorkspaceName = try content.value(String?.self, forProperty: "clockify_workspace_name")
            clockifyProjectName = try content.value(String?.self, forProperty: "clockify_project_name")
            harvestAccountName = try content.value(String?.self, forProperty: "harvest_account_name")
            harvestProjectName = try content.value(String?.self, forProperty: "harvest_project_name")
            harvestTaskName = try content.value(String?.self, forProperty: "harvest_task_name")
            tags = try content.value([String].self, forProperty: "tags")
            billable = try content.value(Bool?.self, forProperty: "billable")
        }

        var generatedContent: GeneratedContent {
            GeneratedContent(
                kind: .structure(
                    properties: [
                        "date_local": GeneratedContent(dateLocal),
                        "start_local": GeneratedContent(startLocal),
                        "stop_local": GeneratedContent(stopLocal),
                        "description": GeneratedContent(description),
                        "toggl_workspace_name": togglWorkspaceName.map { GeneratedContent($0) } ?? GeneratedContent(kind: .null),
                        "toggl_project_name": togglProjectName.map { GeneratedContent($0) } ?? GeneratedContent(kind: .null),
                        "clockify_workspace_name": clockifyWorkspaceName.map { GeneratedContent($0) } ?? GeneratedContent(kind: .null),
                        "clockify_project_name": clockifyProjectName.map { GeneratedContent($0) } ?? GeneratedContent(kind: .null),
                        "harvest_account_name": harvestAccountName.map { GeneratedContent($0) } ?? GeneratedContent(kind: .null),
                        "harvest_project_name": harvestProjectName.map { GeneratedContent($0) } ?? GeneratedContent(kind: .null),
                        "harvest_task_name": harvestTaskName.map { GeneratedContent($0) } ?? GeneratedContent(kind: .null),
                        "tags": GeneratedContent(tags),
                        "billable": billable.map(GeneratedContent.init) ?? GeneratedContent(kind: .null)
                    ],
                    orderedKeys: [
                        "date_local",
                        "start_local",
                        "stop_local",
                        "description",
                        "toggl_workspace_name",
                        "toggl_project_name",
                        "clockify_workspace_name",
                        "clockify_project_name",
                        "harvest_account_name",
                        "harvest_project_name",
                        "harvest_task_name",
                        "tags",
                        "billable"
                    ]
                )
            )
        }

        var asPlannerEntry: GeminiExtractionResponse.Entry {
            GeminiExtractionResponse.Entry(
                dateLocal: dateLocal,
                startLocal: startLocal,
                stopLocal: stopLocal,
                description: description,
                togglWorkspaceName: togglWorkspaceName?.trimmed.nilIfBlank,
                togglProjectName: togglProjectName?.trimmed.nilIfBlank,
                clockifyWorkspaceName: clockifyWorkspaceName?.trimmed.nilIfBlank,
                clockifyProjectName: clockifyProjectName?.trimmed.nilIfBlank,
                harvestAccountName: harvestAccountName?.trimmed.nilIfBlank,
                harvestProjectName: harvestProjectName?.trimmed.nilIfBlank,
                harvestTaskName: harvestTaskName?.trimmed.nilIfBlank,
                tags: tags.map(\.trimmed).filter { !$0.isEmpty },
                billable: billable
            )
        }
    }
}
