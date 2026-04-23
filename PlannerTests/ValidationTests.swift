import Foundation
import Testing

@testable import Tajnica_sp

struct ValidationTests {
    @Test
    func detectsOverlaps() {
        let selectedDay = TestSupport.selectedDay()
        let validator = TimeEntryValidator()

        let first = CandidateTimeEntry(
            date: selectedDay,
            start: TestSupport.localDate(on: selectedDay, hour: 9, minute: 0),
            stop: TestSupport.localDate(on: selectedDay, hour: 10, minute: 0),
            description: "First",
            source: .user
        )
        let second = CandidateTimeEntry(
            date: selectedDay,
            start: TestSupport.localDate(on: selectedDay, hour: 9, minute: 30),
            stop: TestSupport.localDate(on: selectedDay, hour: 11, minute: 0),
            description: "Second",
            source: .user
        )

        let entries = validator.validate(entries: [first, second])

        #expect(entries[0].validationIssues.contains(where: { $0.message.contains("overlaps") }))
        #expect(entries[1].validationIssues.contains(where: { $0.message.contains("overlaps") }))
    }

    @Test
    func rejectsZeroAndNegativeDurations() {
        let selectedDay = TestSupport.selectedDay()
        let validator = TimeEntryValidator()

        let zeroDuration = CandidateTimeEntry(
            date: selectedDay,
            start: TestSupport.localDate(on: selectedDay, hour: 10, minute: 0),
            stop: TestSupport.localDate(on: selectedDay, hour: 10, minute: 0),
            description: "Zero",
            source: .user
        )
        let negativeDuration = CandidateTimeEntry(
            date: selectedDay,
            start: TestSupport.localDate(on: selectedDay, hour: 11, minute: 0),
            stop: TestSupport.localDate(on: selectedDay, hour: 10, minute: 30),
            description: "Negative",
            source: .user
        )

        let entries = validator.validate(entries: [zeroDuration, negativeDuration])

        #expect(entries[0].validationIssues.contains(where: { $0.message.contains("zero duration") }))
        #expect(entries[1].validationIssues.contains(where: { $0.message.contains("after start") }))
    }
}
