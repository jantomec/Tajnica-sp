import Foundation
import Testing

@testable import Tajnica_sp

struct TogglPayloadTests {
    @Test
    func convertsCandidateEntryIntoTogglPayload() throws {
        let selectedDay = TestSupport.selectedDay()
        let entry = CandidateTimeEntry(
            date: selectedDay,
            start: TestSupport.localDate(on: selectedDay, hour: 13, minute: 0),
            stop: TestSupport.localDate(on: selectedDay, hour: 14, minute: 30),
            description: "  Ship release  ",
            togglTarget: .init(
                workspaceName: "Toggl Workspace",
                workspaceId: 99,
                projectName: "Planner",
                projectId: 77
            ),
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

    @Test
    func convertsCandidateEntryIntoClockifyPayload() {
        let selectedDay = TestSupport.selectedDay()
        let entry = CandidateTimeEntry(
            date: selectedDay,
            start: TestSupport.localDate(on: selectedDay, hour: 13, minute: 0),
            stop: TestSupport.localDate(on: selectedDay, hour: 14, minute: 30),
            description: "  Ship release  ",
            billable: false,
            source: .user
        )

        let payload = ClockifyTimeEntryCreateRequest.make(from: entry)

        #expect(payload.description == "Ship release")
        #expect(payload.billable == false)
        #expect(payload.projectId == nil)
    }

    @Test
    func convertsCandidateEntryIntoHarvestPayloads() {
        let selectedDay = TestSupport.selectedDay()
        let entry = CandidateTimeEntry(
            date: selectedDay,
            start: TestSupport.localDate(on: selectedDay, hour: 8, minute: 15),
            stop: TestSupport.localDate(on: selectedDay, hour: 9, minute: 45),
            description: "Support rotation",
            source: .user
        )

        let timestampPayload = HarvestTimestampTimeEntryCreateRequest.make(
            from: entry,
            projectID: 7,
            taskID: 9
        )
        let durationPayload = HarvestDurationTimeEntryCreateRequest.make(
            from: entry,
            projectID: 7,
            taskID: 9
        )

        #expect(timestampPayload.notes == "Support rotation")
        #expect(timestampPayload.spentDate == HarvestDateFormatter.harvestDayString(from: entry.date))
        #expect(timestampPayload.startedTime == HarvestDateFormatter.harvestTimeString(from: entry.start))
        #expect(timestampPayload.endedTime == HarvestDateFormatter.harvestTimeString(from: entry.stop))
        #expect(timestampPayload.projectId == 7)
        #expect(timestampPayload.taskId == 9)

        #expect(durationPayload.notes == "Support rotation")
        #expect(durationPayload.spentDate == HarvestDateFormatter.harvestDayString(from: entry.date))
        #expect(durationPayload.hours == 1.5)
        #expect(durationPayload.projectId == 7)
        #expect(durationPayload.taskId == 9)
    }

    @Test
    func storedEntryRecordCapturesProviderSpecificPayloads() {
        let selectedDay = TestSupport.selectedDay()
        let entry = CandidateTimeEntry(
            date: selectedDay,
            start: TestSupport.localDate(on: selectedDay, hour: 9, minute: 0),
            stop: TestSupport.localDate(on: selectedDay, hour: 10, minute: 0),
            description: "Client work",
            togglTarget: .init(
                workspaceName: "Toggl Workspace",
                workspaceId: 99,
                projectName: "Planner",
                projectId: 42
            ),
            clockifyTarget: .init(
                workspaceName: "Clockify Workspace",
                workspaceId: "clockify-1",
                projectName: nil,
                projectId: nil
            ),
            harvestTarget: .init(
                accountName: "Harvest Account",
                accountId: 3,
                projectName: "Harvest Project",
                projectId: 4,
                taskName: "Implementation",
                taskId: 5
            ),
            tags: ["client"],
            billable: true,
            source: .user
        )

        let record = StoredTimeEntryRecord(
            entry: entry
        )

        #expect(record.toggl?.workspaceID == 99)
        #expect(record.toggl?.request.projectId == 42)
        #expect(record.clockify?.workspaceID == "clockify-1")
        #expect(record.harvest?.accountID == 3)
        #expect(record.harvest?.timestampRequest.projectId == 4)
        #expect(record.harvest?.timestampRequest.taskId == 5)
    }
}
