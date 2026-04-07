import Foundation

struct ValidationIssue: Identifiable, Codable, Equatable, Hashable {
    enum Severity: String, Codable, Equatable, Hashable, CaseIterable {
        case warning
        case error
    }

    var id: UUID
    var severity: Severity
    var field: String?
    var message: String

    init(
        id: UUID = UUID(),
        severity: Severity,
        field: String? = nil,
        message: String
    ) {
        self.id = id
        self.severity = severity
        self.field = field
        self.message = message
    }
}
