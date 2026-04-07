import Foundation

struct GeminiExtractionResponse: Codable, Equatable {
    struct Entry: Codable, Equatable, Identifiable {
        var id: UUID = UUID()
        var dateLocal: String?
        var startLocal: String
        var stopLocal: String
        var description: String
        var projectName: String?
        var tags: [String]
        var billable: Bool?

        enum CodingKeys: String, CodingKey {
            case dateLocal = "date_local"
            case startLocal = "start_local"
            case stopLocal = "stop_local"
            case description
            case projectName = "project_name"
            case tags
            case billable
        }
    }

    var entries: [Entry]
    var assumptions: [String]
    var summary: String?
}
