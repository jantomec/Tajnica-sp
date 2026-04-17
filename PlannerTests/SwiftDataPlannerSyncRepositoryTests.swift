import Foundation
import Testing

@testable import Tajnica_sp

@MainActor
struct SwiftDataPlannerSyncRepositoryTests {
    @MainActor
    @Test
    func loadSnapshotRestoresDraftWithCurrentDayInsteadOfStoredDay() throws {
        let context = RepositoryTestContext()
        defer { context.cleanup() }

        let storedDay = TestSupport.selectedDay(year: 2026, month: 4, day: 2)
        let currentDay = TestSupport.selectedDay(year: 2026, month: 4, day: 8)
        let draft = PlannerDraft(
            note: DailyNoteInput(date: storedDay, rawText: "Synced draft"),
            candidateEntries: [],
            assumptions: [],
            summary: nil,
            lastProcessedAt: nil
        )

        try context.repository.saveDraft(draft)

        let snapshot = try context.repository.loadSnapshot(currentDay: currentDay)

        #expect(snapshot.draft?.note.rawText == "Synced draft")
        #expect(snapshot.draft?.note.date == currentDay)
    }

    @MainActor
    @Test
    func upsertsSubmittedEntriesWithoutDuplicatingIdentifiers() throws {
        let context = RepositoryTestContext()
        defer { context.cleanup() }

        let selectedDay = TestSupport.selectedDay()
        let first = StoredTimeEntryRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000100")!,
            submittedAt: selectedDay,
            baseEntry: .init(
                date: selectedDay,
                start: TestSupport.localDate(on: selectedDay, hour: 9, minute: 0),
                stop: TestSupport.localDate(on: selectedDay, hour: 10, minute: 0),
                description: "Initial description",
                tags: [],
                billable: nil,
                source: .user
            )
        )
        let updated = StoredTimeEntryRecord(
            id: first.id,
            submittedAt: selectedDay,
            baseEntry: .init(
                date: selectedDay,
                start: first.start,
                stop: first.stop,
                description: "Updated description",
                tags: [],
                billable: nil,
                source: .user
            ),
            toggl: .init(
                workspaceID: 1,
                workspaceName: "Workspace",
                request: TogglTimeEntryCreateRequest(
                    billable: nil,
                    createdWith: AppConfiguration.createdWith,
                    description: "Updated description",
                    duration: 3_600,
                    projectId: nil,
                    start: "2026-04-02T09:00:00.000Z",
                    stop: "2026-04-02T10:00:00.000Z",
                    tags: [],
                    workspaceId: 1
                )
            )
        )

        _ = try context.repository.upsertStoredEntries([first])
        _ = try context.repository.upsertStoredEntries([updated])

        let snapshot = try context.repository.loadSnapshot(currentDay: selectedDay)

        #expect(snapshot.storedEntries.count == 1)
        #expect(snapshot.storedEntries.first?.description == "Updated description")
    }
}

struct PlannerPersistenceControllerTests {
    @Test
    func fallsBackForMissingICloudAccountError() {
        let noAccountError = NSError(
            domain: NSCocoaErrorDomain,
            code: 134400,
            userInfo: [
                NSLocalizedFailureReasonErrorKey: "Unable to initialize without an iCloud account (CKAccountStatusNoAccount)."
            ]
        )
        let containerError = NSError(
            domain: NSCocoaErrorDomain,
            code: 134060,
            userInfo: [
                "encounteredErrors": [noAccountError]
            ]
        )

        #expect(PlannerPersistenceController.shouldFallBackToLocalStore(for: containerError))
    }

    @Test
    func doesNotFallBackForUnrelatedPersistenceError() {
        let unrelatedError = NSError(
            domain: NSCocoaErrorDomain,
            code: 134060,
            userInfo: [
                NSLocalizedFailureReasonErrorKey: "Persistent store metadata is incompatible with the current model."
            ]
        )

        #expect(!PlannerPersistenceController.shouldFallBackToLocalStore(for: unrelatedError))
    }

}

@MainActor
private struct RepositoryTestContext {
    let repository: SwiftDataPlannerSyncRepository

    init() {
        let controller = try! PlannerPersistenceController.inMemory()
        self.repository = controller.repository
    }

    func cleanup() {}
}
