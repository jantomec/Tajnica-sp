import Foundation

struct StoredTimeEntryRecord: Identifiable, Codable, Equatable, Hashable {
    struct BaseEntry: Codable, Equatable, Hashable {
        var date: Date
        var start: Date
        var stop: Date
        var description: String
        var tags: [String]
        var billable: Bool?
        var source: CandidateTimeEntry.Source
    }

    struct TogglSubmission: Codable, Equatable, Hashable {
        var workspaceID: Int
        var workspaceName: String
        var projectName: String? = nil
        var request: TogglTimeEntryCreateRequest
    }

    struct ClockifySubmission: Codable, Equatable, Hashable {
        var workspaceID: String
        var workspaceName: String
        var projectName: String? = nil
        var request: ClockifyTimeEntryCreateRequest
    }

    struct HarvestSubmission: Codable, Equatable, Hashable {
        var accountID: Int
        var accountName: String
        var projectID: Int
        var projectName: String
        var taskID: Int
        var taskName: String
        var timestampRequest: HarvestTimestampTimeEntryCreateRequest
        var durationFallbackRequest: HarvestDurationTimeEntryCreateRequest
    }

    var id: UUID
    var diaryPromptRecordID: UUID?
    var submittedAt: Date
    var baseEntry: BaseEntry
    var toggl: TogglSubmission?
    var clockify: ClockifySubmission?
    var harvest: HarvestSubmission?

    init(
        id: UUID = UUID(),
        diaryPromptRecordID: UUID? = nil,
        submittedAt: Date = .now,
        baseEntry: BaseEntry,
        toggl: TogglSubmission? = nil,
        clockify: ClockifySubmission? = nil,
        harvest: HarvestSubmission? = nil
    ) {
        self.id = id
        self.diaryPromptRecordID = diaryPromptRecordID
        self.submittedAt = submittedAt
        self.baseEntry = baseEntry
        self.toggl = toggl
        self.clockify = clockify
        self.harvest = harvest
    }

    init(
        entry: CandidateTimeEntry,
        submittedAt: Date = .now,
        diaryPromptRecordID: UUID? = nil
    ) {
        let normalizedEntry = CandidateTimeEntry(
            id: entry.id,
            date: entry.date,
            start: entry.start,
            stop: entry.stop,
            description: entry.description.trimmed,
            togglTarget: Self.normalizedTogglTarget(entry.togglTarget),
            clockifyTarget: Self.normalizedClockifyTarget(entry.clockifyTarget),
            harvestTarget: Self.normalizedHarvestTarget(entry.harvestTarget),
            tags: entry.tags.trimmedDeduplicated(),
            billable: entry.billable,
            source: entry.source,
            validationIssues: []
        )

        self.id = normalizedEntry.id
        self.diaryPromptRecordID = diaryPromptRecordID
        self.submittedAt = submittedAt
        self.baseEntry = BaseEntry(
            date: normalizedEntry.date,
            start: normalizedEntry.start,
            stop: normalizedEntry.stop,
            description: normalizedEntry.description,
            tags: normalizedEntry.tags,
            billable: normalizedEntry.billable,
            source: normalizedEntry.source
        )

        if let togglTarget = normalizedEntry.togglTarget,
           let workspaceID = togglTarget.workspaceId,
           let workspaceName = togglTarget.workspaceName {
            self.toggl = TogglSubmission(
                workspaceID: workspaceID,
                workspaceName: workspaceName,
                projectName: togglTarget.projectName,
                request: TogglTimeEntryCreateRequest.make(from: normalizedEntry, workspaceID: workspaceID)
            )
        } else {
            self.toggl = nil
        }

        if let clockifyTarget = normalizedEntry.clockifyTarget,
           let workspaceID = clockifyTarget.workspaceId,
           let workspaceName = clockifyTarget.workspaceName {
            self.clockify = ClockifySubmission(
                workspaceID: workspaceID,
                workspaceName: workspaceName,
                projectName: clockifyTarget.projectName,
                request: ClockifyTimeEntryCreateRequest.make(
                    from: normalizedEntry,
                    projectId: clockifyTarget.projectId
                )
            )
        } else {
            self.clockify = nil
        }

        if let harvestTarget = normalizedEntry.harvestTarget,
           let accountID = harvestTarget.accountId,
           let accountName = harvestTarget.accountName,
           let projectID = harvestTarget.projectId,
           let projectName = harvestTarget.projectName,
           let taskID = harvestTarget.taskId,
           let taskName = harvestTarget.taskName {
            self.harvest = HarvestSubmission(
                accountID: accountID,
                accountName: accountName,
                projectID: projectID,
                projectName: projectName,
                taskID: taskID,
                taskName: taskName,
                timestampRequest: HarvestTimestampTimeEntryCreateRequest.make(
                    from: normalizedEntry,
                    projectID: projectID,
                    taskID: taskID
                ),
                durationFallbackRequest: HarvestDurationTimeEntryCreateRequest.make(
                    from: normalizedEntry,
                    projectID: projectID,
                    taskID: taskID
                )
            )
        } else {
            self.harvest = nil
        }
    }

    var date: Date { baseEntry.date }
    var start: Date { baseEntry.start }
    var stop: Date { baseEntry.stop }
    var description: String { baseEntry.description }

    private static func normalizedTogglTarget(_ target: CandidateTimeEntry.TogglTarget?) -> CandidateTimeEntry.TogglTarget? {
        guard let target else { return nil }
        let normalized = CandidateTimeEntry.TogglTarget(
            workspaceName: target.workspaceName?.trimmed.nilIfBlank,
            workspaceId: target.workspaceId,
            projectName: target.projectName?.trimmed.nilIfBlank,
            projectId: target.projectId
        )
        return normalized.hasSelection ? normalized : nil
    }

    private static func normalizedClockifyTarget(_ target: CandidateTimeEntry.ClockifyTarget?) -> CandidateTimeEntry.ClockifyTarget? {
        guard let target else { return nil }
        let normalized = CandidateTimeEntry.ClockifyTarget(
            workspaceName: target.workspaceName?.trimmed.nilIfBlank,
            workspaceId: target.workspaceId?.trimmed.nilIfBlank,
            projectName: target.projectName?.trimmed.nilIfBlank,
            projectId: target.projectId?.trimmed.nilIfBlank
        )
        return normalized.hasSelection ? normalized : nil
    }

    private static func normalizedHarvestTarget(_ target: CandidateTimeEntry.HarvestTarget?) -> CandidateTimeEntry.HarvestTarget? {
        guard let target else { return nil }
        let normalized = CandidateTimeEntry.HarvestTarget(
            accountName: target.accountName?.trimmed.nilIfBlank,
            accountId: target.accountId,
            projectName: target.projectName?.trimmed.nilIfBlank,
            projectId: target.projectId,
            taskName: target.taskName?.trimmed.nilIfBlank,
            taskId: target.taskId
        )
        return normalized.hasSelection ? normalized : nil
    }
}
