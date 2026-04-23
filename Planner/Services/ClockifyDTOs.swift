import Foundation

struct ClockifyCurrentUserDTO: Decodable, Equatable {
    let id: String
    let name: String?
    let email: String?
    let activeWorkspace: String?
    let defaultWorkspace: String?
}

struct ClockifyWorkspaceDTO: Decodable, Equatable {
    let id: String
    let name: String
}

struct ClockifyProjectDTO: Decodable, Equatable {
    let id: String
    let name: String
}

struct ClockifyCreatedTimeEntryDTO: Decodable, Equatable {
    let id: String
    let description: String?
}

struct ClockifyTimeEntryCreateRequest: Codable, Equatable, Hashable {
    let billable: Bool?
    let description: String
    let end: String
    let projectId: String?
    let start: String

    enum CodingKeys: String, CodingKey {
        case billable
        case description
        case end
        case projectId
        case start
    }

    static func make(from entry: CandidateTimeEntry, projectId: String? = nil) -> ClockifyTimeEntryCreateRequest {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        return ClockifyTimeEntryCreateRequest(
            billable: entry.billable,
            description: entry.description.trimmed,
            end: formatter.string(from: entry.stop),
            projectId: projectId,
            start: formatter.string(from: entry.start)
        )
    }
}
