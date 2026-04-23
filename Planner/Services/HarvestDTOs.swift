import Foundation

struct HarvestAccountsEnvelopeDTO: Decodable, Equatable {
    let accounts: [HarvestAccountDTO]
}

struct HarvestAccountDTO: Decodable, Equatable {
    let id: Int
    let name: String
}

struct HarvestCurrentUserDTO: Decodable, Equatable {
    let id: Int
    let firstName: String?
    let lastName: String?
    let email: String?
}

struct HarvestProjectAssignmentsEnvelopeDTO: Decodable, Equatable {
    let projectAssignments: [HarvestProjectAssignmentDTO]
}

struct HarvestProjectAssignmentDTO: Decodable, Equatable {
    struct ProjectDTO: Decodable, Equatable {
        let id: Int
        let name: String
    }

    struct TaskAssignmentDTO: Decodable, Equatable {
        struct TaskDTO: Decodable, Equatable {
            let id: Int
            let name: String
        }

        let billable: Bool?
        let isActive: Bool?
        let task: TaskDTO
    }

    let isActive: Bool?
    let project: ProjectDTO
    let taskAssignments: [TaskAssignmentDTO]
}

struct HarvestCreatedTimeEntryDTO: Decodable, Equatable {
    let id: Int
    let notes: String?
}

struct HarvestTimestampTimeEntryCreateRequest: Codable, Equatable, Hashable {
    let endedTime: String
    let notes: String
    let projectId: Int
    let spentDate: String
    let startedTime: String
    let taskId: Int

    enum CodingKeys: String, CodingKey {
        case endedTime = "ended_time"
        case notes
        case projectId = "project_id"
        case spentDate = "spent_date"
        case startedTime = "started_time"
        case taskId = "task_id"
    }

    static func make(
        from entry: CandidateTimeEntry,
        projectID: Int,
        taskID: Int
    ) -> HarvestTimestampTimeEntryCreateRequest {
        HarvestTimestampTimeEntryCreateRequest(
            endedTime: HarvestDateFormatter.harvestTimeString(from: entry.stop),
            notes: entry.description.trimmed,
            projectId: projectID,
            spentDate: HarvestDateFormatter.harvestDayString(from: entry.date),
            startedTime: HarvestDateFormatter.harvestTimeString(from: entry.start),
            taskId: taskID
        )
    }
}

struct HarvestDurationTimeEntryCreateRequest: Codable, Equatable, Hashable {
    let hours: Double
    let notes: String
    let projectId: Int
    let spentDate: String
    let taskId: Int

    enum CodingKeys: String, CodingKey {
        case hours
        case notes
        case projectId = "project_id"
        case spentDate = "spent_date"
        case taskId = "task_id"
    }

    static func make(
        from entry: CandidateTimeEntry,
        projectID: Int,
        taskID: Int
    ) -> HarvestDurationTimeEntryCreateRequest {
        HarvestDurationTimeEntryCreateRequest(
            hours: entry.duration / 3_600,
            notes: entry.description.trimmed,
            projectId: projectID,
            spentDate: HarvestDateFormatter.harvestDayString(from: entry.date),
            taskId: taskID
        )
    }
}

enum HarvestDateFormatter {
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "h:mma"
        return formatter
    }()

    static func harvestDayString(from date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func harvestTimeString(from date: Date) -> String {
        timeFormatter.string(from: date).lowercased()
    }
}
