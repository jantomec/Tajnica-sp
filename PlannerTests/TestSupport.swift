import Foundation

@testable import Planner

enum TestSupport {
    static let timeZone = TimeZone(identifier: "Europe/Ljubljana")!

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    static func selectedDay(year: Int = 2026, month: Int = 4, day: Int = 2) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12, minute: 0))!
    }

    static func localDate(on selectedDay: Date, hour: Int, minute: Int) -> Date {
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: selectedDay)
        return calendar.date(
            from: DateComponents(
                year: dayComponents.year,
                month: dayComponents.month,
                day: dayComponents.day,
                hour: hour,
                minute: minute
            )
        )!
    }
}
