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

    var credentialLabel: String {
        switch self {
        case .toggl: "Toggl API Token"
        case .clockify: "Clockify API Key"
        case .harvest: "Harvest Access Token"
        }
    }

    var connectInstructions: String {
        switch self {
        case .toggl:
            "Open Toggl Track, go to Profile Settings, and copy the API token from the API Token section."
        case .clockify:
            "Open Clockify, go to Profile Settings, then Preferences, and copy the API key from the API section."
        case .harvest:
            "Open Harvest account settings, go to Developers, and create or copy a personal access token."
        }
    }

    var dialogButtonTitle: String {
        switch self {
        case .toggl, .clockify, .harvest:
            "Connect"
        }
    }

    var disconnectButtonTitle: String {
        switch self {
        case .toggl, .clockify, .harvest:
            "Disconnect"
        }
    }
}
