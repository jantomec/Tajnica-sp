import Foundation

struct WorkspaceSummary: Identifiable, Codable, Equatable, Hashable {
    var id: Int
    var name: String
}

struct ProjectSummary: Identifiable, Codable, Equatable, Hashable {
    var id: Int
    var name: String
    var workspaceId: Int
}
