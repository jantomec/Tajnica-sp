import Foundation

struct DailyNoteInput: Identifiable, Codable, Equatable {
    var id: UUID
    var date: Date
    var rawText: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        rawText: String,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.rawText = rawText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
