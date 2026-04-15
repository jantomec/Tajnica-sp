import Foundation

enum DiaryFeedItem: Identifiable, Equatable {
    case dateSeparator(Date)
    case prompt(DiaryPromptRecord)

    var id: String {
        switch self {
        case let .dateSeparator(day):
            "separator-\(day.timeIntervalSinceReferenceDate)"
        case let .prompt(record):
            "prompt-\(record.id.uuidString)"
        }
    }

    static func makeFeedItems(from records: [DiaryPromptRecord]) -> [DiaryFeedItem] {
        let sortedRecords = records.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id.uuidString > rhs.id.uuidString
            }

            return lhs.createdAt > rhs.createdAt
        }

        var items: [DiaryFeedItem] = []
        var currentDay: Date?

        for record in sortedRecords {
            if currentDay != record.day {
                items.append(.dateSeparator(record.day))
                currentDay = record.day
            }

            items.append(.prompt(record))
        }

        return items
    }
}
