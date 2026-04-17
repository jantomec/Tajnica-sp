import Foundation

struct PlannerIntentError: LocalizedError, Equatable, Sendable {
    let message: String

    var errorDescription: String? {
        message
    }
}

@MainActor
struct PlannerIntentFacade {
    private let persistenceController: PlannerPersistenceController?
    private let appModel: PlannerAppModel
    private let startsModelOnUse: Bool

    init(
        persistenceController: PlannerPersistenceController? = nil,
        appModel: PlannerAppModel,
        startsModelOnUse: Bool = false
    ) {
        self.persistenceController = persistenceController
        self.appModel = appModel
        self.startsModelOnUse = startsModelOnUse
    }

    static func live() throws -> PlannerIntentFacade {
        let persistenceController = try PlannerPersistenceController.live()
        let appModel = PlannerAppModel.live(
            syncRepository: persistenceController.repository,
            storageSyncMode: persistenceController.syncMode
        )

        return PlannerIntentFacade(
            persistenceController: persistenceController,
            appModel: appModel,
            startsModelOnUse: true
        )
    }

    func appendToCurrentDraft(_ noteText: String) async throws -> String {
        try await prepareForIntent()

        let trimmed = noteText.trimmed
        guard !trimmed.isEmpty else {
            throw PlannerIntentError(message: "The note text cannot be empty.")
        }

        appModel.appendToDraft(trimmed)
        return "Added to today's Planner draft. \(draftOverview())"
    }

    func addCurrentDraftEntry(
        description: String,
        start: Date,
        stop: Date
    ) async throws -> String {
        try await prepareForIntent()

        let trimmedDescription = description.trimmed
        guard !trimmedDescription.isEmpty else {
            throw PlannerIntentError(message: "The entry description cannot be empty.")
        }

        let alignedStart = LocalTimeParser.shift(start, to: appModel.draft.note.date, in: .autoupdatingCurrent)
        let alignedStop = LocalTimeParser.shift(stop, to: appModel.draft.note.date, in: .autoupdatingCurrent)

        guard alignedStop > alignedStart else {
            throw PlannerIntentError(message: "The end time must be after the start time.")
        }

        appModel.addDraftEntry(
            description: trimmedDescription,
            start: alignedStart,
            stop: alignedStop
        )

        let range = PlannerFormatters.timeRange(start: alignedStart, stop: alignedStop)
        return "Added draft entry \"\(trimmedDescription)\" for \(range). \(draftOverview())"
    }

    func updateCurrentDraftEntry(
        id: UUID,
        description: String?,
        start: Date?,
        stop: Date?
    ) async throws -> String {
        try await prepareForIntent()

        guard description != nil || start != nil || stop != nil else {
            throw PlannerIntentError(message: "Provide at least one change for the draft entry.")
        }

        guard var entry = appModel.draft.candidateEntries.first(where: { $0.id == id }) else {
            throw PlannerIntentError(message: "That draft entry is no longer available.")
        }

        if let description {
            guard let trimmedDescription = description.trimmed.nilIfBlank else {
                throw PlannerIntentError(message: "The updated entry description cannot be empty.")
            }

            entry.description = trimmedDescription
        }

        if let start {
            entry.start = LocalTimeParser.shift(start, to: entry.date, in: .autoupdatingCurrent)
        }

        if let stop {
            entry.stop = LocalTimeParser.shift(stop, to: entry.date, in: .autoupdatingCurrent)
        }

        guard entry.stop > entry.start else {
            throw PlannerIntentError(message: "The end time must be after the start time.")
        }

        appModel.saveEditedEntry(entry)

        let title = entry.description.isBlank ? "Untitled Entry" : entry.description
        let range = PlannerFormatters.timeRange(start: entry.start, stop: entry.stop)
        return "Updated draft entry \"\(title)\" for \(range). \(draftOverview())"
    }

    func deleteCurrentDraftEntry(id: UUID) async throws -> String {
        try await prepareForIntent()

        guard let entry = appModel.draft.candidateEntries.first(where: { $0.id == id }) else {
            throw PlannerIntentError(message: "That draft entry is no longer available.")
        }

        let title = entry.description.isBlank ? "Untitled Entry" : entry.description
        appModel.deleteEntry(id: id)
        return "Deleted draft entry \"\(title)\". \(draftOverview())"
    }

    func duplicateCurrentDraftEntry(id: UUID) async throws -> String {
        try await prepareForIntent()

        guard let entry = appModel.draft.candidateEntries.first(where: { $0.id == id }) else {
            throw PlannerIntentError(message: "That draft entry is no longer available.")
        }

        let title = entryTitle(entry)
        appModel.duplicateEntry(id: id)
        return "Duplicated draft entry \"\(title)\". \(draftOverview())"
    }

    func setCurrentDraftEntryBillable(
        id: UUID,
        billable: Bool?
    ) async throws -> String {
        try await prepareForIntent()

        guard let entry = appModel.draft.candidateEntries.first(where: { $0.id == id }) else {
            throw PlannerIntentError(message: "That draft entry is no longer available.")
        }

        appModel.setEntryBillable(id: id, billable: billable)

        let state: String
        switch billable {
        case true:
            state = "billable"
        case false:
            state = "non-billable"
        case nil:
            state = "unset"
        }

        return "Marked \"\(entryTitle(entry))\" as \(state). \(draftOverview())"
    }

    func setCurrentDraftEntryTags(
        id: UUID,
        tags: [String]
    ) async throws -> String {
        try await prepareForIntent()

        guard let entry = appModel.draft.candidateEntries.first(where: { $0.id == id }) else {
            throw PlannerIntentError(message: "That draft entry is no longer available.")
        }

        let normalizedTags = tags.trimmedDeduplicated()
        appModel.setEntryTags(id: id, tags: normalizedTags)

        if normalizedTags.isEmpty {
            return "Cleared tags for \"\(entryTitle(entry))\". \(draftOverview())"
        }

        let tagList = normalizedTags.map { "#\($0)" }.joined(separator: ", ")
        return "Updated tags for \"\(entryTitle(entry))\" to \(tagList). \(draftOverview())"
    }

    func assignTogglWorkspace(
        entryID: UUID,
        workspaceID: Int
    ) async throws -> String {
        try await prepareForIntent()
        try await appModel.ensureTrackerCatalogsLoaded(for: .toggl)

        guard appModel.enabledTimeTrackers.contains(.toggl) else {
            throw PlannerIntentError(message: "Toggl is not connected in Planner.")
        }

        guard let entry = appModel.draft.candidateEntries.first(where: { $0.id == entryID }) else {
            throw PlannerIntentError(message: "That draft entry is no longer available.")
        }

        guard let workspace = appModel.togglWorkspaceCatalogs.first(where: { $0.workspace.id == workspaceID }) else {
            throw PlannerIntentError(message: "That Toggl workspace is no longer available.")
        }

        appModel.setTogglAssignment(id: entryID, workspaceID: workspaceID, projectID: nil)
        return "Assigned Toggl workspace \"\(workspace.workspace.name)\" to \"\(entryTitle(entry))\". \(draftOverview())"
    }

    func assignTogglProject(
        entryID: UUID,
        workspaceID: Int,
        projectID: Int
    ) async throws -> String {
        try await prepareForIntent()
        try await appModel.ensureTrackerCatalogsLoaded(for: .toggl)

        guard appModel.enabledTimeTrackers.contains(.toggl) else {
            throw PlannerIntentError(message: "Toggl is not connected in Planner.")
        }

        guard let entry = appModel.draft.candidateEntries.first(where: { $0.id == entryID }) else {
            throw PlannerIntentError(message: "That draft entry is no longer available.")
        }

        guard let workspace = appModel.togglWorkspaceCatalogs.first(where: { $0.workspace.id == workspaceID }),
              let project = workspace.projects.first(where: { $0.id == projectID }) else {
            throw PlannerIntentError(message: "That Toggl project is no longer available.")
        }

        appModel.setTogglAssignment(id: entryID, workspaceID: workspaceID, projectID: projectID)
        return "Assigned Toggl project \"\(project.name)\" in \"\(workspace.workspace.name)\" to \"\(entryTitle(entry))\". \(draftOverview())"
    }

    func assignClockifyWorkspace(
        entryID: UUID,
        workspaceID: String
    ) async throws -> String {
        try await prepareForIntent()
        try await appModel.ensureTrackerCatalogsLoaded(for: .clockify)

        guard appModel.enabledTimeTrackers.contains(.clockify) else {
            throw PlannerIntentError(message: "Clockify is not connected in Planner.")
        }

        guard let entry = appModel.draft.candidateEntries.first(where: { $0.id == entryID }) else {
            throw PlannerIntentError(message: "That draft entry is no longer available.")
        }

        guard let workspace = appModel.clockifyWorkspaceCatalogs.first(where: { $0.workspace.id == workspaceID }) else {
            throw PlannerIntentError(message: "That Clockify workspace is no longer available.")
        }

        appModel.setClockifyAssignment(id: entryID, workspaceID: workspaceID, projectID: nil)
        return "Assigned Clockify workspace \"\(workspace.workspace.name)\" to \"\(entryTitle(entry))\". \(draftOverview())"
    }

    func assignClockifyProject(
        entryID: UUID,
        workspaceID: String,
        projectID: String
    ) async throws -> String {
        try await prepareForIntent()
        try await appModel.ensureTrackerCatalogsLoaded(for: .clockify)

        guard appModel.enabledTimeTrackers.contains(.clockify) else {
            throw PlannerIntentError(message: "Clockify is not connected in Planner.")
        }

        guard let entry = appModel.draft.candidateEntries.first(where: { $0.id == entryID }) else {
            throw PlannerIntentError(message: "That draft entry is no longer available.")
        }

        guard let workspace = appModel.clockifyWorkspaceCatalogs.first(where: { $0.workspace.id == workspaceID }),
              let project = workspace.projects.first(where: { $0.id == projectID }) else {
            throw PlannerIntentError(message: "That Clockify project is no longer available.")
        }

        appModel.setClockifyAssignment(id: entryID, workspaceID: workspaceID, projectID: projectID)
        return "Assigned Clockify project \"\(project.name)\" in \"\(workspace.workspace.name)\" to \"\(entryTitle(entry))\". \(draftOverview())"
    }

    func assignHarvestTask(
        entryID: UUID,
        accountID: Int,
        projectID: Int,
        taskID: Int
    ) async throws -> String {
        try await prepareForIntent()
        try await appModel.ensureTrackerCatalogsLoaded(for: .harvest)

        guard appModel.enabledTimeTrackers.contains(.harvest) else {
            throw PlannerIntentError(message: "Harvest is not connected in Planner.")
        }

        guard let entry = appModel.draft.candidateEntries.first(where: { $0.id == entryID }) else {
            throw PlannerIntentError(message: "That draft entry is no longer available.")
        }

        guard let account = appModel.harvestAccountCatalogs.first(where: { $0.account.id == accountID }),
              let project = account.projects.first(where: { $0.id == projectID }),
              let task = project.taskAssignments.first(where: { $0.id == taskID }) else {
            throw PlannerIntentError(message: "That Harvest task is no longer available.")
        }

        appModel.setHarvestAssignment(
            id: entryID,
            accountID: accountID,
            projectID: projectID,
            taskID: taskID
        )

        return "Assigned Harvest task \"\(task.name)\" in project \"\(project.name)\" to \"\(entryTitle(entry))\". \(draftOverview())"
    }

    func clearTrackerAssignment(
        entryID: UUID,
        provider: TimeTrackerProvider
    ) async throws -> String {
        try await prepareForIntent()

        guard let entry = appModel.draft.candidateEntries.first(where: { $0.id == entryID }) else {
            throw PlannerIntentError(message: "That draft entry is no longer available.")
        }

        appModel.clearTrackerAssignment(id: entryID, provider: provider)
        return "Cleared the \(provider.displayName) assignment for \"\(entryTitle(entry))\". \(draftOverview())"
    }

    func processCurrentDraft() async throws -> String {
        try await prepareForIntent()

        guard !appModel.draft.note.rawText.trimmed.isEmpty else {
            throw PlannerIntentError(message: "Your current Planner draft note is empty.")
        }

        guard appModel.draft.candidateEntries.isEmpty else {
            throw PlannerIntentError(
                message: "The current draft already has candidate entries. Open the app to review or regenerate them."
            )
        }

        await appModel.processNote()

        if let error = appModel.captureErrorMessage?.trimmed.nilIfBlank {
            throw PlannerIntentError(message: error)
        }

        if let status = appModel.captureStatusMessage?.trimmed.nilIfBlank {
            return status
        }

        return "Processed today's Planner draft. \(draftOverview())"
    }

    func showCurrentDraftSummary() async throws -> String {
        try await prepareForIntent()
        return draftOverview()
    }

    func submitCurrentDraft() async throws -> String {
        try await prepareForIntent()

        guard !appModel.draft.candidateEntries.isEmpty else {
            throw PlannerIntentError(message: "There are no draft entries to submit.")
        }

        await appModel.submitEntries()

        if let error = appModel.reviewErrorMessage?.trimmed.nilIfBlank {
            if let status = appModel.reviewStatusMessage?.trimmed.nilIfBlank {
                return "\(status) \(error)"
            }

            throw PlannerIntentError(message: error)
        }

        if let status = appModel.captureStatusMessage?.trimmed.nilIfBlank {
            return status
        }

        if let status = appModel.reviewStatusMessage?.trimmed.nilIfBlank {
            return status
        }

        throw PlannerIntentError(message: "Planner did not return a submission result.")
    }

    private func prepareForIntent() async throws {
        _ = persistenceController

        if startsModelOnUse {
            await appModel.start()
        }

        appModel.refreshNoteDateForPresentation()
    }

    private func draftOverview() -> String {
        let date = PlannerFormatters.dateString(appModel.draft.note.date)
        let noteState = appModel.draft.note.rawText.trimmed.isEmpty ? "the note is empty" : "the note has text"
        let entryCount = appModel.draft.candidateEntries.count
        let entryState: String

        switch entryCount {
        case 0:
            entryState = "there are no candidate entries yet"
        case 1:
            entryState = "there is 1 candidate entry"
        default:
            entryState = "there are \(entryCount) candidate entries"
        }

        var parts = [noteState, entryState]

        if appModel.totalErrorCount > 0 {
            let label = appModel.totalErrorCount == 1 ? "validation error" : "validation errors"
            parts.append("\(appModel.totalErrorCount) \(label)")
        }

        if appModel.totalWarningCount > 0 {
            let label = appModel.totalWarningCount == 1 ? "warning" : "warnings"
            parts.append("\(appModel.totalWarningCount) \(label)")
        }

        return "For \(date), \(parts.joined(separator: ", "))."
    }

    private func entryTitle(_ entry: CandidateTimeEntry) -> String {
        entry.description.isBlank ? "Untitled Entry" : entry.description
    }
}
