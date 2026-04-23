import Foundation

extension String {
    nonisolated var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated var nilIfBlank: String? {
        let value = trimmed
        return value.isEmpty ? nil : value
    }

    nonisolated var isBlank: Bool {
        trimmed.isEmpty
    }
}

extension Array where Element == String {
    nonisolated func trimmedDeduplicated() -> [String] {
        var seen = Set<String>()
        var values: [String] = []

        for value in self {
            let trimmedValue = value.trimmed
            guard !trimmedValue.isEmpty else { continue }

            let key = trimmedValue.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )

            if seen.insert(key).inserted {
                values.append(trimmedValue)
            }
        }

        return values
    }
}
