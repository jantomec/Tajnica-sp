import Foundation
import Testing

@testable import Planner

struct TogglPayloadTests {
    @Test
    func convertsCandidateEntryIntoTogglPayload() throws {
        let selectedDay = TestSupport.selectedDay()
        let entry = CandidateTimeEntry(
            date: selectedDay,
            start: TestSupport.localDate(on: selectedDay, hour: 13, minute: 0),
            stop: TestSupport.localDate(on: selectedDay, hour: 14, minute: 30),
            description: "  Ship release  ",
            projectName: "Planner",
            projectId: 77,
            workspaceId: 99,
            tags: ["release", " ios ", "release"],
            billable: false,
            source: .user
        )

        let payload = TogglTimeEntryCreateRequest.make(from: entry, workspaceID: 99)

        #expect(payload.createdWith == AppConfiguration.createdWith)
        #expect(payload.description == "Ship release")
        #expect(payload.duration == 5_400)
        #expect(payload.projectId == 77)
        #expect(payload.workspaceId == 99)
        #expect(payload.tags == ["release", "ios"])
        #expect(payload.billable == false)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        #expect(formatter.date(from: payload.start) != nil)
        #expect(formatter.date(from: payload.stop) != nil)
    }
}
