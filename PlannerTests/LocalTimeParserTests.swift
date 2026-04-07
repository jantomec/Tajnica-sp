import Foundation
import Testing

@testable import Planner

struct LocalTimeParserTests {
    @Test
    func parsesHHmmForSelectedDayAndTimezone() throws {
        let selectedDay = TestSupport.selectedDay()
        let parsed = try LocalTimeParser.parse("09:45", on: selectedDay, in: TestSupport.timeZone)

        let components = TestSupport.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: parsed)

        #expect(components.year == 2026)
        #expect(components.month == 4)
        #expect(components.day == 2)
        #expect(components.hour == 9)
        #expect(components.minute == 45)
    }

    @Test
    func parses2400AsNextDayStart() throws {
        let selectedDay = TestSupport.selectedDay()
        let parsed = try LocalTimeParser.parse("24:00", on: selectedDay, in: TestSupport.timeZone)

        let components = TestSupport.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: parsed)

        #expect(components.year == 2026)
        #expect(components.month == 4)
        #expect(components.day == 3)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
    }
}
