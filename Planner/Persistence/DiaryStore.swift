import Foundation

final class DiaryStore {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileURL: URL

    init(fileManager: FileManager = .default, applicationName: String = AppConfiguration.appName) {
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.fileURL = baseDirectory
            .appendingPathComponent(applicationName, isDirectory: true)
            .appendingPathComponent("diary.json")
    }

    func loadPromptHistory() throws -> [DiaryPromptRecord] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([DiaryPromptRecord].self, from: data)
    }

    func save(_ records: [DiaryPromptRecord]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(records)
        try data.write(to: fileURL, options: .atomic)
    }

    func append(_ record: DiaryPromptRecord) throws {
        var records = try loadPromptHistory()
        records.append(record)
        try save(records)
    }
}
