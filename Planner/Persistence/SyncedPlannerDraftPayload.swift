import Foundation

struct SyncedPlannerDraftPayload: Codable, Equatable {
    var note: SyncedDailyNotePayload
    var candidateEntries: [SyncedCandidateTimeEntryPayload]
    var assumptions: [String]
    var summary: String?
    var lastProcessedAt: Date?
    var sourceDiaryPromptID: UUID?

    @MainActor
    init(draft: PlannerDraft) {
        note = SyncedDailyNotePayload(note: draft.note)
        candidateEntries = draft.candidateEntries.map(SyncedCandidateTimeEntryPayload.init(entry:))
        assumptions = draft.assumptions
        summary = draft.summary
        lastProcessedAt = draft.lastProcessedAt
        sourceDiaryPromptID = draft.sourceDiaryPromptID
    }

    func makeDraft(currentDay: Date) -> PlannerDraft {
        PlannerDraft(
            note: note.makeNote(currentDay: currentDay),
            candidateEntries: candidateEntries.map(\.candidateTimeEntry),
            assumptions: assumptions,
            summary: summary,
            lastProcessedAt: lastProcessedAt,
            sourceDiaryPromptID: sourceDiaryPromptID
        )
    }
}

struct SyncedDailyNotePayload: Codable, Equatable {
    var id: UUID
    var rawText: String
    var createdAt: Date
    var updatedAt: Date

    init(note: DailyNoteInput) {
        id = note.id
        rawText = note.rawText
        createdAt = note.createdAt
        updatedAt = note.updatedAt
    }

    func makeNote(currentDay: Date) -> DailyNoteInput {
        DailyNoteInput(
            id: id,
            date: currentDay,
            rawText: rawText,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct SyncedCandidateTimeEntryPayload: Codable, Equatable {
    var id: UUID
    var date: Date
    var start: Date
    var stop: Date
    var description: String
    var togglTarget: CandidateTimeEntry.TogglTarget?
    var clockifyTarget: CandidateTimeEntry.ClockifyTarget?
    var harvestTarget: CandidateTimeEntry.HarvestTarget?
    var tags: [String]
    var billable: Bool?
    var source: CandidateTimeEntry.Source

    init(entry: CandidateTimeEntry) {
        id = entry.id
        date = entry.date
        start = entry.start
        stop = entry.stop
        description = entry.description
        togglTarget = entry.togglTarget
        clockifyTarget = entry.clockifyTarget
        harvestTarget = entry.harvestTarget
        tags = entry.tags
        billable = entry.billable
        source = entry.source
    }

    var candidateTimeEntry: CandidateTimeEntry {
        CandidateTimeEntry(
            id: id,
            date: date,
            start: start,
            stop: stop,
            description: description,
            togglTarget: togglTarget,
            clockifyTarget: clockifyTarget,
            harvestTarget: harvestTarget,
            tags: tags,
            billable: billable,
            source: source,
            validationIssues: []
        )
    }
}
