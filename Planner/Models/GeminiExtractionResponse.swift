import Foundation

struct GeminiExtractionResponse: Codable, Equatable {
    struct Entry: Codable, Equatable, Identifiable {
        var id: UUID = UUID()
        var dateLocal: String?
        var startLocal: String
        var stopLocal: String
        var description: String
        var togglWorkspaceName: String?
        var togglProjectName: String?
        var clockifyWorkspaceName: String?
        var clockifyProjectName: String?
        var harvestAccountName: String?
        var harvestProjectName: String?
        var harvestTaskName: String?
        var tags: [String]
        var billable: Bool?

        enum CodingKeys: String, CodingKey {
            case dateLocal = "date_local"
            case startLocal = "start_local"
            case stopLocal = "stop_local"
            case description
            case togglWorkspaceName = "toggl_workspace_name"
            case togglProjectName = "toggl_project_name"
            case clockifyWorkspaceName = "clockify_workspace_name"
            case clockifyProjectName = "clockify_project_name"
            case harvestAccountName = "harvest_account_name"
            case harvestProjectName = "harvest_project_name"
            case harvestTaskName = "harvest_task_name"
            case tags
            case billable
        }
    }

    var entries: [Entry]
    var assumptions: [String]
    var summary: String?
}
