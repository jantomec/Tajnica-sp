import Foundation

struct WorkspaceSummary: Identifiable, Codable, Equatable, Hashable {
    var id: Int
    var name: String
}

struct TogglWorkspaceCatalog: Identifiable, Codable, Equatable, Hashable {
    var workspace: WorkspaceSummary
    var projects: [ProjectSummary]

    var id: Int { workspace.id }
}

struct ClockifyWorkspaceSummary: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
}

struct ClockifyProjectSummary: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var workspaceId: String
}

struct ClockifyWorkspaceCatalog: Identifiable, Codable, Equatable, Hashable {
    var workspace: ClockifyWorkspaceSummary
    var projects: [ClockifyProjectSummary]

    var id: String { workspace.id }
}

struct ProjectSummary: Identifiable, Codable, Equatable, Hashable {
    var id: Int
    var name: String
    var workspaceId: Int
}

struct HarvestAccountSummary: Identifiable, Codable, Equatable, Hashable {
    var id: Int
    var name: String
}

struct HarvestTaskSummary: Identifiable, Codable, Equatable, Hashable {
    var id: Int
    var name: String
}

struct HarvestProjectSummary: Identifiable, Codable, Equatable, Hashable {
    var id: Int
    var name: String
    var taskAssignments: [HarvestTaskSummary]
}

struct HarvestAccountCatalog: Identifiable, Codable, Equatable, Hashable {
    var account: HarvestAccountSummary
    var projects: [HarvestProjectSummary]

    var id: Int { account.id }
}
