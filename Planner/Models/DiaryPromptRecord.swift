import Foundation

struct DiaryPromptRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var day: Date
    var rawText: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        day: Date,
        rawText: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.day = day
        self.rawText = rawText
        self.createdAt = createdAt
    }
}
