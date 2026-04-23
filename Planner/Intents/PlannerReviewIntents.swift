import AppIntents
import Foundation

enum TrackerAssignmentProviderIntent: String, AppEnum {
    case toggl
    case clockify
    case harvest

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Time Tracker")
    static let caseDisplayRepresentations: [TrackerAssignmentProviderIntent: DisplayRepresentation] = [
        .toggl: "Toggl",
        .clockify: "Clockify",
        .harvest: "Harvest"
    ]

    var provider: TimeTrackerProvider {
        switch self {
        case .toggl:
            return .toggl
        case .clockify:
            return .clockify
        case .harvest:
            return .harvest
        }
    }
}

enum DraftEntryBillableStateIntent: String, AppEnum {
    case billable
    case nonBillable
    case unset

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Billable Setting")
    static let caseDisplayRepresentations: [DraftEntryBillableStateIntent: DisplayRepresentation] = [
        .billable: "Billable",
        .nonBillable: "Non-billable",
        .unset: "Not Set"
    ]

    var value: Bool? {
        switch self {
        case .billable:
            return true
        case .nonBillable:
            return false
        case .unset:
            return nil
        }
    }
}

struct DuplicateDraftEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "Duplicate Draft Entry"
    static let description = IntentDescription("Create a copy of one entry in the current draft.")
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Draft Entry",
        requestValueDialog: IntentDialog("Which draft entry should I duplicate?")
    )
    var entry: DraftEntryEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Duplicate \(\.$entry)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let facade = try await MainActor.run { try PlannerIntentFacade.live() }
        let message = try await facade.duplicateCurrentDraftEntry(id: entry.id)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}

struct SetDraftEntryBillableIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Entry Billable State"
    static let description = IntentDescription("Mark a current draft entry as billable, non-billable, or not set.")
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Draft Entry",
        requestValueDialog: IntentDialog("Which draft entry should I update?")
    )
    var entry: DraftEntryEntity

    @Parameter(
        title: "Billable Setting",
        requestValueDialog: IntentDialog("Should it be billable, non-billable, or not set?")
    )
    var billableState: DraftEntryBillableStateIntent

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$entry) to \(\.$billableState)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let facade = try await MainActor.run { try PlannerIntentFacade.live() }
        let message = try await facade.setCurrentDraftEntryBillable(
            id: entry.id,
            billable: billableState.value
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}

struct SetDraftEntryTagsIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Entry Tags"
    static let description = IntentDescription("Replace the tags on a current draft entry using a comma-separated tag list.")
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Draft Entry",
        requestValueDialog: IntentDialog("Which draft entry should I tag?")
    )
    var entry: DraftEntryEntity

    @Parameter(
        title: "Tag List",
        requestValueDialog: IntentDialog("What tags should I set?")
    )
    var tagsText: String

    static var parameterSummary: some ParameterSummary {
        Summary("Set tags on \(\.$entry) to \(\.$tagsText)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let facade = try await MainActor.run { try PlannerIntentFacade.live() }
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        let message = try await facade.setCurrentDraftEntryTags(id: entry.id, tags: tags)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}

struct AssignTogglWorkspaceIntent: AppIntent {
    static let title: LocalizedStringResource = "Assign Toggl Workspace"
    static let description = IntentDescription("Set the Toggl workspace for a current draft entry.")
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Draft Entry",
        requestValueDialog: IntentDialog("Which draft entry should I assign?")
    )
    var entry: DraftEntryEntity

    @Parameter(
        title: "Toggl Workspace",
        requestValueDialog: IntentDialog("Which Toggl workspace should I use?")
    )
    var workspace: TogglWorkspaceEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Assign \(\.$workspace) to \(\.$entry)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let facade = try await MainActor.run { try PlannerIntentFacade.live() }
        let message = try await facade.assignTogglWorkspace(
            entryID: entry.id,
            workspaceID: workspace.id
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}

struct AssignTogglProjectIntent: AppIntent {
    static let title: LocalizedStringResource = "Assign Toggl Project"
    static let description = IntentDescription("Set the Toggl project for a current draft entry.")
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Draft Entry",
        requestValueDialog: IntentDialog("Which draft entry should I assign?")
    )
    var entry: DraftEntryEntity

    @Parameter(
        title: "Toggl Project",
        requestValueDialog: IntentDialog("Which Toggl project should I use?")
    )
    var project: TogglProjectEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Assign \(\.$project) to \(\.$entry)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let facade = try await MainActor.run { try PlannerIntentFacade.live() }
        let message = try await facade.assignTogglProject(
            entryID: entry.id,
            workspaceID: project.workspaceID,
            projectID: project.projectID
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}

struct AssignClockifyWorkspaceIntent: AppIntent {
    static let title: LocalizedStringResource = "Assign Clockify Workspace"
    static let description = IntentDescription("Set the Clockify workspace for a current draft entry.")
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Draft Entry",
        requestValueDialog: IntentDialog("Which draft entry should I assign?")
    )
    var entry: DraftEntryEntity

    @Parameter(
        title: "Clockify Workspace",
        requestValueDialog: IntentDialog("Which Clockify workspace should I use?")
    )
    var workspace: ClockifyWorkspaceEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Assign \(\.$workspace) to \(\.$entry)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let facade = try await MainActor.run { try PlannerIntentFacade.live() }
        let message = try await facade.assignClockifyWorkspace(
            entryID: entry.id,
            workspaceID: workspace.id
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}

struct AssignClockifyProjectIntent: AppIntent {
    static let title: LocalizedStringResource = "Assign Clockify Project"
    static let description = IntentDescription("Set the Clockify project for a current draft entry.")
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Draft Entry",
        requestValueDialog: IntentDialog("Which draft entry should I assign?")
    )
    var entry: DraftEntryEntity

    @Parameter(
        title: "Clockify Project",
        requestValueDialog: IntentDialog("Which Clockify project should I use?")
    )
    var project: ClockifyProjectEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Assign \(\.$project) to \(\.$entry)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let facade = try await MainActor.run { try PlannerIntentFacade.live() }
        let message = try await facade.assignClockifyProject(
            entryID: entry.id,
            workspaceID: project.workspaceID,
            projectID: project.projectID
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}

struct AssignHarvestTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Assign Harvest Task"
    static let description = IntentDescription("Set the Harvest task for a current draft entry.")
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Draft Entry",
        requestValueDialog: IntentDialog("Which draft entry should I assign?")
    )
    var entry: DraftEntryEntity

    @Parameter(
        title: "Harvest Task",
        requestValueDialog: IntentDialog("Which Harvest task should I use?")
    )
    var task: HarvestTaskEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Assign \(\.$task) to \(\.$entry)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let facade = try await MainActor.run { try PlannerIntentFacade.live() }
        let message = try await facade.assignHarvestTask(
            entryID: entry.id,
            accountID: task.accountID,
            projectID: task.projectID,
            taskID: task.taskID
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}

struct ClearTrackerAssignmentIntent: AppIntent {
    static let title: LocalizedStringResource = "Clear Tracker Assignment"
    static let description = IntentDescription("Remove the selected tracker assignment from a current draft entry.")
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Draft Entry",
        requestValueDialog: IntentDialog("Which draft entry should I update?")
    )
    var entry: DraftEntryEntity

    @Parameter(
        title: "Time Tracker",
        requestValueDialog: IntentDialog("Which tracker assignment should I clear?")
    )
    var provider: TrackerAssignmentProviderIntent

    static var parameterSummary: some ParameterSummary {
        Summary("Clear the \(\.$provider) assignment for \(\.$entry)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let facade = try await MainActor.run { try PlannerIntentFacade.live() }
        let message = try await facade.clearTrackerAssignment(
            entryID: entry.id,
            provider: provider.provider
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
