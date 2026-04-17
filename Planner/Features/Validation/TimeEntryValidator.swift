import Foundation

protocol TimeEntryValidating {
    func validate(
        entries: [CandidateTimeEntry],
        enabledTrackers: Set<TimeTrackerProvider>,
        togglWorkspaces: [TogglWorkspaceCatalog],
        clockifyWorkspaces: [ClockifyWorkspaceCatalog],
        harvestAccounts: [HarvestAccountCatalog]
    ) -> [CandidateTimeEntry]
}

struct TimeEntryValidator: TimeEntryValidating {
    let longEntryThreshold: TimeInterval
    let largeGapThreshold: TimeInterval

    init(
        longEntryThreshold: TimeInterval = AppConfiguration.longEntryWarningThreshold,
        largeGapThreshold: TimeInterval = AppConfiguration.largeGapWarningThreshold
    ) {
        self.longEntryThreshold = longEntryThreshold
        self.largeGapThreshold = largeGapThreshold
    }

    func validate(
        entries: [CandidateTimeEntry],
        enabledTrackers: Set<TimeTrackerProvider> = [],
        togglWorkspaces: [TogglWorkspaceCatalog] = [],
        clockifyWorkspaces: [ClockifyWorkspaceCatalog] = [],
        harvestAccounts: [HarvestAccountCatalog] = []
    ) -> [CandidateTimeEntry] {
        var normalized = entries.map { entry in
            var copy = entry
            copy.description = copy.description.trimmed
            if var togglTarget = copy.togglTarget {
                togglTarget.workspaceName = togglTarget.workspaceName?.trimmed.nilIfBlank
                togglTarget.projectName = togglTarget.projectName?.trimmed.nilIfBlank
                copy.togglTarget = togglTarget.hasSelection ? togglTarget : nil
            }
            if var clockifyTarget = copy.clockifyTarget {
                clockifyTarget.workspaceName = clockifyTarget.workspaceName?.trimmed.nilIfBlank
                clockifyTarget.workspaceId = clockifyTarget.workspaceId?.trimmed.nilIfBlank
                clockifyTarget.projectName = clockifyTarget.projectName?.trimmed.nilIfBlank
                clockifyTarget.projectId = clockifyTarget.projectId?.trimmed.nilIfBlank
                copy.clockifyTarget = clockifyTarget.hasSelection ? clockifyTarget : nil
            }
            if var harvestTarget = copy.harvestTarget {
                harvestTarget.accountName = harvestTarget.accountName?.trimmed.nilIfBlank
                harvestTarget.projectName = harvestTarget.projectName?.trimmed.nilIfBlank
                harvestTarget.taskName = harvestTarget.taskName?.trimmed.nilIfBlank
                copy.harvestTarget = harvestTarget.hasSelection ? harvestTarget : nil
            }
            copy.tags = copy.tags.trimmedDeduplicated()
            copy.validationIssues = []
            return copy
        }
        .sorted { $0.start < $1.start }

        for index in normalized.indices {
            var issues: [ValidationIssue] = []
            let entry = normalized[index]

            if entry.description.isBlank {
                issues.append(
                    ValidationIssue(
                        severity: .error,
                        field: "description",
                        message: "Description cannot be blank."
                    )
                )
            }

            if entry.stop == entry.start {
                issues.append(
                    ValidationIssue(
                        severity: .error,
                        field: "stop",
                        message: "Entries cannot have zero duration."
                    )
                )
            } else if entry.stop < entry.start {
                issues.append(
                    ValidationIssue(
                        severity: .error,
                        field: "stop",
                        message: "End time must be after start time."
                    )
                )
            }

            if entry.duration > longEntryThreshold {
                issues.append(
                    ValidationIssue(
                        severity: .warning,
                        field: "stop",
                        message: "This entry is unusually long."
                    )
                )
            }

            if let togglTarget = entry.togglTarget,
               togglTarget.projectId != nil,
               togglTarget.workspaceId == nil {
                issues.append(
                    ValidationIssue(
                        severity: .error,
                        field: "togglTarget.projectId",
                        message: "A Toggl project assignment needs a workspace."
                    )
                )
            }

            if enabledTrackers.contains(.toggl), togglWorkspaces.isEmpty {
                issues.append(
                    ValidationIssue(
                        severity: .error,
                        field: "togglTarget.workspaceId",
                        message: "Toggl workspace data is unavailable. Reconnect Toggl or try again."
                    )
                )
            } else if enabledTrackers.contains(.toggl),
                      entry.togglTarget?.workspaceId == nil {
                issues.append(
                    ValidationIssue(
                        severity: .error,
                        field: "togglTarget.workspaceId",
                        message: "Choose a Toggl workspace for this entry."
                    )
                )
            }

            if enabledTrackers.contains(.clockify), clockifyWorkspaces.isEmpty {
                issues.append(
                    ValidationIssue(
                        severity: .error,
                        field: "clockifyTarget.workspaceId",
                        message: "Clockify workspace data is unavailable. Reconnect Clockify or try again."
                    )
                )
            } else if enabledTrackers.contains(.clockify),
                      entry.clockifyTarget?.workspaceId?.trimmed.nilIfBlank == nil {
                issues.append(
                    ValidationIssue(
                        severity: .error,
                        field: "clockifyTarget.workspaceId",
                        message: "Choose a Clockify workspace for this entry."
                    )
                )
            }

            if enabledTrackers.contains(.harvest), harvestAccounts.isEmpty {
                issues.append(
                    ValidationIssue(
                        severity: .error,
                        field: "harvestTarget.accountId",
                        message: "Harvest assignment data is unavailable. Reconnect Harvest or try again."
                    )
                )
            } else if enabledTrackers.contains(.harvest),
                      entry.harvestTarget?.accountId == nil {
                issues.append(
                    ValidationIssue(
                        severity: .error,
                        field: "harvestTarget.accountId",
                        message: "Choose a Harvest account for this entry."
                    )
                )
            }

            if enabledTrackers.contains(.harvest),
               !harvestAccounts.isEmpty,
               entry.harvestTarget?.projectId == nil {
                issues.append(
                    ValidationIssue(
                        severity: .error,
                        field: "harvestTarget.projectId",
                        message: "Choose a Harvest project for this entry."
                    )
                )
            }

            if enabledTrackers.contains(.harvest),
               !harvestAccounts.isEmpty,
               entry.harvestTarget?.taskId == nil {
                issues.append(
                    ValidationIssue(
                        severity: .error,
                        field: "harvestTarget.taskId",
                        message: "Choose a Harvest task for this entry."
                    )
                )
            }

            normalized[index].validationIssues = issues
        }

        guard normalized.count > 1 else {
            return normalized
        }

        for index in 1..<normalized.count {
            let previous = normalized[index - 1]
            let current = normalized[index]

            if current.start < previous.stop {
                normalized[index - 1].validationIssues.append(
                    ValidationIssue(
                        severity: .error,
                        field: "start",
                        message: "This entry overlaps with the next entry."
                    )
                )
                normalized[index].validationIssues.append(
                    ValidationIssue(
                        severity: .error,
                        field: "start",
                        message: "This entry overlaps with the previous entry."
                    )
                )
            } else {
                let gap = current.start.timeIntervalSince(previous.stop)
                if gap >= largeGapThreshold {
                    normalized[index].validationIssues.append(
                        ValidationIssue(
                            severity: .warning,
                            field: "start",
                            message: "There is a large gap before this entry."
                        )
                    )
                }
            }
        }

        return normalized
    }
}
