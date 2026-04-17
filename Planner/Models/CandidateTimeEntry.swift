import Foundation

struct CandidateTimeEntry: Identifiable, Codable, Equatable {
    enum Source: String, Codable, Equatable, CaseIterable, Hashable {
        case gemini
        case user
    }

    struct TogglTarget: Codable, Equatable, Hashable {
        var workspaceName: String?
        var workspaceId: Int?
        var projectName: String?
        var projectId: Int?

        var hasSelection: Bool {
            workspaceName != nil || workspaceId != nil || projectName != nil || projectId != nil
        }
    }

    struct ClockifyTarget: Codable, Equatable, Hashable {
        var workspaceName: String?
        var workspaceId: String?
        var projectName: String?
        var projectId: String?

        var hasSelection: Bool {
            workspaceName != nil || workspaceId != nil || projectName != nil || projectId != nil
        }
    }

    struct HarvestTarget: Codable, Equatable, Hashable {
        var accountName: String?
        var accountId: Int?
        var projectName: String?
        var projectId: Int?
        var taskName: String?
        var taskId: Int?

        var hasSelection: Bool {
            accountName != nil
                || accountId != nil
                || projectName != nil
                || projectId != nil
                || taskName != nil
                || taskId != nil
        }
    }

    var id: UUID
    var date: Date
    var start: Date
    var stop: Date
    var description: String
    var togglTarget: TogglTarget?
    var clockifyTarget: ClockifyTarget?
    var harvestTarget: HarvestTarget?
    var tags: [String]
    var billable: Bool?
    var source: Source
    var validationIssues: [ValidationIssue]

    init(
        id: UUID = UUID(),
        date: Date,
        start: Date,
        stop: Date,
        description: String,
        togglTarget: TogglTarget? = nil,
        clockifyTarget: ClockifyTarget? = nil,
        harvestTarget: HarvestTarget? = nil,
        tags: [String] = [],
        billable: Bool? = nil,
        source: Source,
        validationIssues: [ValidationIssue] = []
    ) {
        self.id = id
        self.date = date
        self.start = start
        self.stop = stop
        self.description = description
        self.togglTarget = togglTarget
        self.clockifyTarget = clockifyTarget
        self.harvestTarget = harvestTarget
        self.tags = tags
        self.billable = billable
        self.source = source
        self.validationIssues = validationIssues
    }

    var duration: TimeInterval {
        stop.timeIntervalSince(start)
    }

    var hasErrors: Bool {
        validationIssues.contains { $0.severity == .error }
    }

    var hasWarnings: Bool {
        validationIssues.contains { $0.severity == .warning }
    }
}
