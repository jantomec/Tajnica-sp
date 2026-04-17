import Foundation
import Testing

@testable import Tajnica_sp

struct GeminiEntryConversionTests {
    @Test
    func convertsGeminiResponseIntoCandidateEntries() throws {
        let selectedDay = TestSupport.selectedDay()
        let response = GeminiExtractionResponse(
            entries: [
                .init(
                    dateLocal: nil,
                    startLocal: "08:30",
                    stopLocal: "10:00",
                    description: "Client call",
                    togglWorkspaceName: nil,
                    togglProjectName: "Alpha",
                    clockifyWorkspaceName: nil,
                    clockifyProjectName: nil,
                    harvestAccountName: nil,
                    harvestProjectName: nil,
                    harvestTaskName: nil,
                    tags: [" client ", "meeting", "client"],
                    billable: true
                )
            ],
            assumptions: ["Morning block was contiguous."],
            summary: "Two hours of client work."
        )

        let entries = try GeminiEntryConverter.convert(
            response: response,
            selectedDate: selectedDay,
            timeZone: TestSupport.timeZone
        )

        let entry = try #require(entries.first)

        #expect(entries.count == 1)
        #expect(entry.description == "Client call")
        #expect(entry.togglTarget?.projectName == "Alpha")
        #expect(entry.tags == [" client ", "meeting", "client"])
        #expect(entry.billable == true)

        let startComponents = TestSupport.calendar.dateComponents([.hour, .minute], from: entry.start)
        let stopComponents = TestSupport.calendar.dateComponents([.hour, .minute], from: entry.stop)

        #expect(startComponents.hour == 8)
        #expect(startComponents.minute == 30)
        #expect(stopComponents.hour == 10)
        #expect(stopComponents.minute == 0)
    }
}
