import Foundation

struct TogglCurrentUserDTO: Decodable, Equatable {
    let id: Int
    let fullname: String?
    let email: String?
}

struct TogglWorkspaceDTO: Decodable, Equatable {
    let id: Int
    let name: String
}

struct TogglProjectDTO: Decodable, Equatable {
    let id: Int
    let name: String
    let workspaceId: Int
}

struct TogglCreatedTimeEntryDTO: Decodable, Equatable {
    let id: Int
    let description: String?
}

struct TogglTimeEntryCreateRequest: Codable, Equatable, Hashable {
    let billable: Bool?
    let createdWith: String
    let description: String
    let duration: Int
    let projectId: Int?
    let start: String
    let stop: String
    let tags: [String]
    let workspaceId: Int

    enum CodingKeys: String, CodingKey {
        case billable
        case createdWith = "created_with"
        case description
        case duration
        case projectId = "project_id"
        case start
        case stop
        case tags
        case workspaceId = "workspace_id"
    }

    static func make(from entry: CandidateTimeEntry, workspaceID: Int) -> TogglTimeEntryCreateRequest {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        return TogglTimeEntryCreateRequest(
            billable: entry.billable,
            createdWith: AppConfiguration.createdWith,
            description: entry.description.trimmed,
            duration: Int(entry.stop.timeIntervalSince(entry.start)),
            projectId: entry.togglTarget?.projectId,
            start: formatter.string(from: entry.start),
            stop: formatter.string(from: entry.stop),
            tags: entry.tags.trimmedDeduplicated(),
            workspaceId: workspaceID
        )
    }
}
