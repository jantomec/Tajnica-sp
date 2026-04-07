import Foundation

struct CandidateTimeEntry: Identifiable, Codable, Equatable {
    enum Source: String, Codable, Equatable, CaseIterable {
        case gemini
        case user
    }

    var id: UUID
    var date: Date
    var start: Date
    var stop: Date
    var description: String
    var projectName: String?
    var projectId: Int?
    var workspaceId: Int?
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
        projectName: String? = nil,
        projectId: Int? = nil,
        workspaceId: Int? = nil,
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
        self.projectName = projectName
        self.projectId = projectId
        self.workspaceId = workspaceId
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
