import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum AppStorageExportFormat: String, CaseIterable, Identifiable, Codable {
    case toggl
    case clockify
    case harvest

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .toggl:
            "Toggl"
        case .clockify:
            "Clockify"
        case .harvest:
            "Harvest"
        }
    }
}

struct AppStorageExportDateRange: Codable, Equatable {
    var startDate: Date
    var endDate: Date
}

struct TogglAppStorageExportEntry: Codable, Equatable {
    var storedRecordID: UUID
    var submittedAt: Date
    var workspaceID: Int
    var workspaceName: String
    var request: TogglTimeEntryCreateRequest
}

struct ClockifyAppStorageExportEntry: Codable, Equatable {
    var storedRecordID: UUID
    var submittedAt: Date
    var workspaceID: String
    var workspaceName: String
    var request: ClockifyTimeEntryCreateRequest
}

struct HarvestAppStorageExportEntry: Codable, Equatable {
    var storedRecordID: UUID
    var submittedAt: Date
    var accountID: Int
    var accountName: String
    var projectID: Int
    var projectName: String
    var taskID: Int
    var taskName: String
    var timestampRequest: HarvestTimestampTimeEntryCreateRequest
    var durationFallbackRequest: HarvestDurationTimeEntryCreateRequest
}

struct AppStorageExportEnvelope<Entry: Codable & Equatable>: Codable, Equatable {
    var exportedAt: Date
    var storageMode: String
    var format: AppStorageExportFormat
    var dateRange: AppStorageExportDateRange
    var entries: [Entry]
}

struct AppStorageExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
