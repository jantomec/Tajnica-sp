import Foundation

struct PlannerDraft: Codable, Equatable {
    var note: DailyNoteInput
    var candidateEntries: [CandidateTimeEntry]
    var assumptions: [String]
    var summary: String?
    var lastProcessedAt: Date?

    static func empty(on date: Date) -> PlannerDraft {
        PlannerDraft(
            note: DailyNoteInput(date: date, rawText: ""),
            candidateEntries: [],
            assumptions: [],
            summary: nil,
            lastProcessedAt: nil
        )
    }
}
