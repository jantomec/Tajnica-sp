import Foundation

enum GeminiEntryConverter {
    static func convert(
        response: GeminiExtractionResponse,
        selectedDate: Date,
        timeZone: TimeZone
    ) throws -> [CandidateTimeEntry] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        return try response.entries.map { entry in
            let entryDate = resolveDate(entry.dateLocal, fallback: selectedDate, calendar: calendar, timeZone: timeZone)
            let dayStart = calendar.startOfDay(for: entryDate)

            let start = try LocalTimeParser.parse(entry.startLocal, on: entryDate, in: timeZone)
            let stop = try LocalTimeParser.parse(entry.stopLocal, on: entryDate, in: timeZone)

            return CandidateTimeEntry(
                date: dayStart,
                start: start,
                stop: stop,
                description: entry.description,
                projectName: entry.projectName,
                tags: entry.tags,
                billable: entry.billable,
                source: .gemini
            )
        }
    }

    /// Parse a YYYY-MM-DD string into a Date, falling back to the provided date if parsing fails or the field is nil.
    private static func resolveDate(_ dateString: String?, fallback: Date, calendar: Calendar, timeZone: TimeZone) -> Date {
        guard let dateString = dateString?.trimmed, !dateString.isEmpty else {
            return fallback
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timeZone
        formatter.calendar = calendar

        return formatter.date(from: dateString) ?? fallback
    }
}
