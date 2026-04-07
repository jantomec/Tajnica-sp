import Foundation

enum LocalTimeParserError: LocalizedError, Equatable {
    case invalidFormat(String)
    case invalidTime(String)
    case invalidDate(String)

    var errorDescription: String? {
        switch self {
        case let .invalidFormat(value):
            return "Expected HH:mm time, got “\(value)”."
        case let .invalidTime(value):
            return "Time “\(value)” is outside the supported local day."
        case let .invalidDate(value):
            return "Could not construct a valid date for “\(value)”."
        }
    }
}

enum LocalTimeParser {
    static func parse(_ value: String, on selectedDate: Date, in timeZone: TimeZone) throws -> Date {
        let trimmed = value.trimmed
        let pieces = trimmed.split(separator: ":")
        guard pieces.count == 2,
              let hour = Int(pieces[0]),
              let minute = Int(pieces[1]) else {
            throw LocalTimeParserError.invalidFormat(value)
        }

        guard (0...59).contains(minute) else {
            throw LocalTimeParserError.invalidTime(value)
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let startOfDay = calendar.startOfDay(for: selectedDate)

        if hour == 24, minute == 0 {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
                throw LocalTimeParserError.invalidDate(value)
            }
            return nextDay
        }

        guard (0...23).contains(hour) else {
            throw LocalTimeParserError.invalidTime(value)
        }

        let dayComponents = calendar.dateComponents([.year, .month, .day], from: startOfDay)
        var components = DateComponents()
        components.year = dayComponents.year
        components.month = dayComponents.month
        components.day = dayComponents.day
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.timeZone = timeZone

        guard let date = calendar.date(from: components) else {
            throw LocalTimeParserError.invalidDate(value)
        }

        return date
    }

    static func shift(_ sourceDate: Date, to targetDay: Date, in timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let sourceComponents = calendar.dateComponents([.hour, .minute, .second], from: sourceDate)
        let targetDayComponents = calendar.dateComponents([.year, .month, .day], from: calendar.startOfDay(for: targetDay))

        var components = DateComponents()
        components.year = targetDayComponents.year
        components.month = targetDayComponents.month
        components.day = targetDayComponents.day
        components.hour = sourceComponents.hour
        components.minute = sourceComponents.minute
        components.second = sourceComponents.second
        components.timeZone = timeZone

        return calendar.date(from: components) ?? sourceDate
    }
}
