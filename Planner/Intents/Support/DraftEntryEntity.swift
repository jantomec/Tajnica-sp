import AppIntents
import Foundation

struct DraftEntryEntity: AppEntity, Hashable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Planner Draft Entry"
    static let defaultQuery = DraftEntryQuery()

    let id: UUID
    let date: Date
    let start: Date
    let stop: Date
    let descriptionText: String
    let validationIssueCount: Int

    init(entry: CandidateTimeEntry) {
        id = entry.id
        date = entry.date
        start = entry.start
        stop = entry.stop
        descriptionText = entry.description
        validationIssueCount = entry.validationIssues.count
    }

    var displayRepresentation: DisplayRepresentation {
        let title = descriptionText.isBlank ? "Untitled Entry" : descriptionText
        let issueSuffix: String

        if validationIssueCount > 0 {
            let label = validationIssueCount == 1 ? "issue" : "issues"
            issueSuffix = " • \(validationIssueCount) \(label)"
        } else {
            issueSuffix = ""
        }

        let subtitle = "\(PlannerFormatters.dateString(date)) • \(PlannerFormatters.timeRange(start: start, stop: stop))\(issueSuffix)"

        return DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: title),
            subtitle: LocalizedStringResource(stringLiteral: subtitle)
        )
    }
}

struct DraftEntryQuery: EnumerableEntityQuery {
    func entities(for identifiers: [DraftEntryEntity.ID]) async throws -> [DraftEntryEntity] {
        let entries = try await loadCurrentDraftEntries()
        let lookup = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        return identifiers.compactMap { lookup[$0] }
    }

    func allEntities() async throws -> [DraftEntryEntity] {
        try await loadCurrentDraftEntries()
    }

    private func loadCurrentDraftEntries() async throws -> [DraftEntryEntity] {
        try await MainActor.run {
            try PlannerIntentDraftSnapshot.loadCurrentDraftEntries()
        }
    }
}

@MainActor
private enum PlannerIntentDraftSnapshot {
    static func loadCurrentDraftEntries() throws -> [DraftEntryEntity] {
        let persistenceController = try PlannerPersistenceController.live()
        let snapshot = try persistenceController.repository.loadSnapshot(currentDay: currentDay)

        return (snapshot.draft?.candidateEntries ?? [])
            .sorted { lhs, rhs in
                if lhs.start == rhs.start {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.start < rhs.start
            }
            .map(DraftEntryEntity.init(entry:))
    }

    private static var currentDay: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar.startOfDay(for: .now)
    }
}
