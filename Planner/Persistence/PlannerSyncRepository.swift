import Foundation

struct PlannerPersistenceSnapshot {
    var draft: PlannerDraft?
    var diaryPromptHistory: [DiaryPromptRecord]
    var storedEntries: [StoredTimeEntryRecord]
}

@MainActor
protocol PlannerSyncRepository {
    func loadSnapshot(currentDay: Date) throws -> PlannerPersistenceSnapshot
    func saveDraft(_ draft: PlannerDraft) throws
    func clearDraft() throws
    @discardableResult
    func appendDiaryPrompt(_ record: DiaryPromptRecord) throws -> [DiaryPromptRecord]
    @discardableResult
    func upsertStoredEntries(_ entries: [StoredTimeEntryRecord]) throws -> [StoredTimeEntryRecord]
    /// Re-saves every persisted record so SwiftData/CloudKit treats each one as
    /// modified and uploads it again. Used for the one-time push that runs the
    /// first time iCloud becomes available after a local-only run.
    func resyncAllRecords() throws
}
