import Foundation

enum TimeTrackerProvider: String, CaseIterable, Identifiable, Codable {
    case toggl
    case clockify
    case harvest

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .toggl: "Toggl"
        case .clockify: "Clockify"
        case .harvest: "Harvest"
        }
    }

    var isAvailable: Bool {
        switch self {
        case .toggl: true
        case .clockify, .harvest: false
        }
    }

    var credentialLabel: String {
        switch self {
        case .toggl: "Toggl API Token"
        case .clockify: "Clockify API Key"
        case .harvest: "Harvest Access Token"
        }
    }
}
