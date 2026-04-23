import AppIntents
import Foundation

struct AppendToCurrentDraftIntent: AppIntent {
    static let title: LocalizedStringResource = "Append to Current Draft"
    static let description = IntentDescription("Add text to the current draft note.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Text")
    var noteText: String

    static var parameterSummary: some ParameterSummary {
        Summary("Append \(\.$noteText) to the current draft")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let facade = try await MainActor.run { try PlannerIntentFacade.live() }
        let message = try await facade.appendToCurrentDraft(noteText)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}

struct AddDraftEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Draft Entry"
    static let description = IntentDescription("Add a manual time entry to the current draft.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Description")
    var entryDescription: String

    @Parameter(title: "Start Time")
    var startTime: Date

    @Parameter(title: "End Time")
    var endTime: Date

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$entryDescription) from \(\.$startTime) to \(\.$endTime) to the current draft")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let facade = try await MainActor.run { try PlannerIntentFacade.live() }
        let message = try await facade.addCurrentDraftEntry(
            description: entryDescription,
            start: startTime,
            stop: endTime
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}

struct UpdateDraftEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "Update Draft Entry"
    static let description = IntentDescription("Update an existing time entry in the current draft.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Entry")
    var entry: DraftEntryEntity

    @Parameter(title: "New Description")
    var entryDescription: String?

    @Parameter(title: "New Start Time")
    var startTime: Date?

    @Parameter(title: "New End Time")
    var endTime: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("Update \(\.$entry) in the current draft")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let facade = try await MainActor.run { try PlannerIntentFacade.live() }
        let message = try await facade.updateCurrentDraftEntry(
            id: entry.id,
            description: entryDescription,
            start: startTime,
            stop: endTime
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}

struct DeleteDraftEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "Delete Draft Entry"
    static let description = IntentDescription("Delete a time entry from the current draft.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Entry")
    var entry: DraftEntryEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Delete \(\.$entry) from the current draft")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let facade = try await MainActor.run { try PlannerIntentFacade.live() }
        let message = try await facade.deleteCurrentDraftEntry(id: entry.id)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}

struct ProcessCurrentDraftIntent: AppIntent {
    static let title: LocalizedStringResource = "Process Current Draft"
    static let description = IntentDescription("Process the current draft note into candidate time entries.")
    static let supportedModes: IntentModes = .background

    static var parameterSummary: some ParameterSummary {
        Summary("Process the current draft")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let facade = try await MainActor.run { try PlannerIntentFacade.live() }
        let message = try await facade.processCurrentDraft()
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}

struct ShowCurrentDraftSummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Current Draft Summary"
    static let description = IntentDescription("Summarize the current draft note and entries.")
    static let supportedModes: IntentModes = .background

    static var parameterSummary: some ParameterSummary {
        Summary("Show the current draft summary")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let facade = try await MainActor.run { try PlannerIntentFacade.live() }
        let message = try await facade.showCurrentDraftSummary()
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}

struct OpenPlannerCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Capture"
    static let description = IntentDescription("Open the app directly to the Capture tab.")
    static let supportedModes: IntentModes = .foreground

    static var parameterSummary: some ParameterSummary {
        Summary("Open Capture")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = "Opening Capture in \(AppConfiguration.displayName)"
        return .result(
            opensIntent: OpenURLIntent(PlannerDeepLink.capture.url),
            dialog: IntentDialog(stringLiteral: message)
        )
    }
}

struct OpenPlannerReviewIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Review"
    static let description = IntentDescription("Open the app directly to the Review tab.")
    static let supportedModes: IntentModes = .foreground

    @Parameter(title: "Entry")
    var entry: DraftEntryEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Open Review")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message: String
        if let entry {
            let title = entry.descriptionText.isBlank ? "Untitled Entry" : entry.descriptionText
            message = "Opening Review for \"\(title)\" in \(AppConfiguration.displayName)"
        } else {
            message = "Opening Review in \(AppConfiguration.displayName)"
        }

        return .result(
            opensIntent: OpenURLIntent(PlannerDeepLink.review(entryID: entry?.id).url),
            dialog: IntentDialog(stringLiteral: message)
        )
    }
}

struct SubmitCurrentDraftIntent: AppIntent {
    static let title: LocalizedStringResource = "Submit Current Draft"
    static let description = IntentDescription("Submit the current draft entries.")
    static let supportedModes: IntentModes = .background

    static var parameterSummary: some ParameterSummary {
        Summary("Submit the current draft")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let facade = try await MainActor.run { try PlannerIntentFacade.live() }
        let message = try await facade.submitCurrentDraft()
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
