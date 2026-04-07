import Foundation

protocol TimeEntryValidating {
    func validate(entries: [CandidateTimeEntry], submissionWorkspaceID: Int?) -> [CandidateTimeEntry]
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

    func validate(entries: [CandidateTimeEntry], submissionWorkspaceID: Int? = nil) -> [CandidateTimeEntry] {
        var normalized = entries.map { entry in
            var copy = entry
            copy.description = copy.description.trimmed
            copy.projectName = copy.projectName?.trimmed.nilIfBlank
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

            if entry.projectId != nil, entry.workspaceId == nil {
                issues.append(
                    ValidationIssue(
                        severity: .error,
                        field: "projectId",
                        message: "A project assignment needs a workspace."
                    )
                )
            }

            if let submissionWorkspaceID,
               let projectWorkspaceID = entry.workspaceId,
               entry.projectId != nil,
               projectWorkspaceID != submissionWorkspaceID {
                issues.append(
                    ValidationIssue(
                        severity: .error,
                        field: "workspaceId",
                        message: "The assigned project belongs to a different workspace."
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
