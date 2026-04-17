import Foundation
import SwiftData

@Model
final class SyncedDiaryPrompt {
    var recordID: UUID = UUID()
    var day: Date = Date.now
    var rawText: String = ""
    var createdAt: Date = Date.now

    init(
        recordID: UUID = UUID(),
        day: Date,
        rawText: String,
        createdAt: Date = .now
    ) {
        self.recordID = recordID
        self.day = day
        self.rawText = rawText
        self.createdAt = createdAt
    }
}

@Model
final class SyncedCurrentDraft {
    var storageKey: String = ""
    var payloadJSON: String = ""
    var updatedAt: Date = Date.now
    var createdAt: Date = Date.now

    init(
        storageKey: String,
        payloadJSON: String,
        updatedAt: Date = .now,
        createdAt: Date = .now
    ) {
        self.storageKey = storageKey
        self.payloadJSON = payloadJSON
        self.updatedAt = updatedAt
        self.createdAt = createdAt
    }
}

@Model
final class SyncedStoredTimeEntry {
    var recordID: UUID = UUID()
    var start: Date = Date.now
    var stop: Date = Date.now
    var submittedAt: Date = Date.now
    var payloadJSON: String = ""

    init(
        recordID: UUID,
        start: Date,
        stop: Date,
        submittedAt: Date,
        payloadJSON: String
    ) {
        self.recordID = recordID
        self.start = start
        self.stop = stop
        self.submittedAt = submittedAt
        self.payloadJSON = payloadJSON
    }
}

@MainActor
final class SwiftDataPlannerSyncRepository: PlannerSyncRepository {
    private enum Constants {
        static let currentDraftStorageKey = "current-draft"
    }

    private let modelContainer: ModelContainer
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadSnapshot(currentDay: Date) throws -> PlannerPersistenceSnapshot {
        let context = modelContainer.mainContext
        let diaryModels = try canonicalDiaryPrompts(in: context)
        let draftModel = try canonicalCurrentDraft(in: context)

        let draft = try draftModel.map {
            try decodeDraft(from: $0.payloadJSON, currentDay: currentDay)
        }

        return PlannerPersistenceSnapshot(
            draft: draft,
            diaryPromptHistory: diaryModels.map(\.diaryPromptRecord),
            storedEntries: try canonicalStoredEntries(in: context).map(decodeStoredEntry(from:))
        )
    }

    func saveDraft(_ draft: PlannerDraft) throws {
        let context = modelContainer.mainContext
        let draftModel = try canonicalCurrentDraft(in: context) ?? SyncedCurrentDraft(
            storageKey: Constants.currentDraftStorageKey,
            payloadJSON: ""
        )

        if draftModel.modelContext == nil {
            context.insert(draftModel)
        }

        draftModel.storageKey = Constants.currentDraftStorageKey
        draftModel.payloadJSON = try encodeDraft(draft)
        draftModel.updatedAt = .now
        if draftModel.createdAt > draftModel.updatedAt {
            draftModel.createdAt = draftModel.updatedAt
        }

        try save(context)
    }

    func clearDraft() throws {
        let context = modelContainer.mainContext
        let drafts = try context.fetch(FetchDescriptor<SyncedCurrentDraft>())
        drafts.forEach(context.delete)
        try save(context)
    }

    @discardableResult
    func appendDiaryPrompt(_ record: DiaryPromptRecord) throws -> [DiaryPromptRecord] {
        let context = modelContainer.mainContext
        let diaryModels = try canonicalDiaryPrompts(in: context)

        if diaryModels.contains(where: { $0.day == record.day && $0.rawText == record.rawText }) {
            return diaryModels.map(\.diaryPromptRecord)
        }

        context.insert(
            SyncedDiaryPrompt(
                recordID: record.id,
                day: record.day,
                rawText: record.rawText,
                createdAt: record.createdAt
            )
        )

        try save(context)
        return try canonicalDiaryPrompts(in: context).map(\.diaryPromptRecord)
    }

    @discardableResult
    func upsertStoredEntries(_ entries: [StoredTimeEntryRecord]) throws -> [StoredTimeEntryRecord] {
        let context = modelContainer.mainContext
        let storedModels = try canonicalStoredEntries(in: context)
        let lookup = Dictionary(uniqueKeysWithValues: storedModels.map { ($0.recordID, $0) })

        for entry in entries {
            let payloadJSON = try encodeStoredEntry(entry)
            let model: SyncedStoredTimeEntry

            if let existing = lookup[entry.id] {
                model = existing
            } else {
                model = SyncedStoredTimeEntry(
                    recordID: entry.id,
                    start: entry.start,
                    stop: entry.stop,
                    submittedAt: entry.submittedAt,
                    payloadJSON: payloadJSON
                )
            }

            if model.modelContext == nil {
                context.insert(model)
            }

            model.recordID = entry.id
            model.start = entry.start
            model.stop = entry.stop
            model.submittedAt = entry.submittedAt
            model.payloadJSON = payloadJSON
        }

        try save(context)
        return try canonicalStoredEntries(in: context).map(decodeStoredEntry(from:))
    }

    private func canonicalDiaryPrompts(in context: ModelContext) throws -> [SyncedDiaryPrompt] {
        let descriptor = FetchDescriptor<SyncedDiaryPrompt>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let prompts = try context.fetch(descriptor)

        var keptRecordIDs = Set<UUID>()
        var keptContentKeys = Set<String>()
        var canonicalPrompts: [SyncedDiaryPrompt] = []
        var deleted = false

        for prompt in prompts {
            let contentKey = Self.diaryContentKey(for: prompt)
            if keptRecordIDs.contains(prompt.recordID) || keptContentKeys.contains(contentKey) {
                context.delete(prompt)
                deleted = true
                continue
            }

            keptRecordIDs.insert(prompt.recordID)
            keptContentKeys.insert(contentKey)
            canonicalPrompts.append(prompt)
        }

        if deleted {
            try save(context)
        }

        return canonicalPrompts.sorted { $0.createdAt < $1.createdAt }
    }

    private func canonicalCurrentDraft(in context: ModelContext) throws -> SyncedCurrentDraft? {
        let descriptor = FetchDescriptor<SyncedCurrentDraft>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let drafts = try context.fetch(descriptor)

        guard let canonical = drafts.first else { return nil }

        if drafts.count > 1 {
            drafts.dropFirst().forEach(context.delete)
            try save(context)
        }

        return canonical
    }

    private func canonicalStoredEntries(in context: ModelContext) throws -> [SyncedStoredTimeEntry] {
        let descriptor = FetchDescriptor<SyncedStoredTimeEntry>(
            sortBy: [SortDescriptor(\.submittedAt, order: .forward)]
        )
        let entries = try context.fetch(descriptor)

        var keptRecordIDs = Set<UUID>()
        var canonicalEntries: [SyncedStoredTimeEntry] = []
        var deleted = false

        for entry in entries {
            if keptRecordIDs.contains(entry.recordID) {
                context.delete(entry)
                deleted = true
                continue
            }

            keptRecordIDs.insert(entry.recordID)
            canonicalEntries.append(entry)
        }

        if deleted {
            try save(context)
        }

        return canonicalEntries.sorted { lhs, rhs in
            if lhs.start == rhs.start {
                return lhs.submittedAt < rhs.submittedAt
            }
            return lhs.start < rhs.start
        }
    }

    private func encodeDraft(_ draft: PlannerDraft) throws -> String {
        let payload = SyncedPlannerDraftPayload(draft: draft)
        let data = try encoder.encode(payload)
        guard let json = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return json
    }

    private func decodeDraft(
        from payloadJSON: String,
        currentDay: Date
    ) throws -> PlannerDraft {
        let data = Data(payloadJSON.utf8)
        let payload = try decoder.decode(SyncedPlannerDraftPayload.self, from: data)
        return payload.makeDraft(currentDay: currentDay)
    }

    private func save(_ context: ModelContext) throws {
        guard context.hasChanges else { return }
        try context.save()
    }

    private func encodeStoredEntry(_ entry: StoredTimeEntryRecord) throws -> String {
        let data = try encoder.encode(entry)
        guard let json = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return json
    }

    private func decodeStoredEntry(from model: SyncedStoredTimeEntry) throws -> StoredTimeEntryRecord {
        let data = Data(model.payloadJSON.utf8)
        return try decoder.decode(StoredTimeEntryRecord.self, from: data)
    }

    private static func diaryContentKey(for prompt: SyncedDiaryPrompt) -> String {
        diaryContentKey(day: prompt.day, rawText: prompt.rawText)
    }

    private static func diaryContentKey(day: Date, rawText: String) -> String {
        "\(day.timeIntervalSinceReferenceDate)|\(rawText)"
    }
}

private extension SyncedDiaryPrompt {
    var diaryPromptRecord: DiaryPromptRecord {
        DiaryPromptRecord(
            id: recordID,
            day: day,
            rawText: rawText,
            createdAt: createdAt
        )
    }
}
