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
}
