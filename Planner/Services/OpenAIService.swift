import Foundation

struct OpenAIService: LLMServicing {
    private let httpClient: HTTPClient
    private let decoder: JSONDecoder

    init(httpClient: HTTPClient, decoder: JSONDecoder = JSONDecoder()) {
        self.httpClient = httpClient
        self.decoder = decoder
    }

    func extractTimeEntries(
        apiKey: String,
        model: String,
        note: DailyNoteInput,
        timeZone: TimeZone,
        userContext: String?,
        availableProjects: [String]
    ) async throws -> GeminiExtractionResponse {
        let isoDate = PlannerFormatters.isoLocalDateString(note.date, timeZone: timeZone)

        var userPrompt = """
        Today's date is \(isoDate).
        Local timezone: \(timeZone.identifier)

        User note:
        \(note.rawText)
        """

        if let context = userContext?.trimmed, !context.isEmpty {
            userPrompt += "\n\nUser context (use this to better understand the user's work patterns):\n\(context)"
        }

        if !availableProjects.isEmpty {
            let list = availableProjects.map { "- \($0)" }.joined(separator: "\n")
            userPrompt += "\n\nAvailable Toggl projects (use the exact name in \"project_name\" when an entry clearly belongs to one; otherwise leave it null):\n\(list)"
        }

        let systemPrompt = """
        Convert the user's note into candidate Toggl time entries.
        Determine the correct date for each entry from the note content. \
        If the note says "yesterday" or references a past day, use that day's date (YYYY-MM-DD). \
        If no specific day is mentioned, default to today's date.
        Each entry MUST include a "date_local" field in YYYY-MM-DD format.
        Infer reasonable contiguous time blocks.
        Do not fabricate high-confidence details that are not supported by the note.
        Keep descriptions concise and suitable for Toggl Track.
        If user context is provided, use it to make better inferences about working hours, typical activities, and project assignments.

        You MUST respond with ONLY a valid JSON object (no markdown, no code blocks) matching this schema:
        {
          "entries": [{"date_local": "YYYY-MM-DD", "start_local": "HH:mm", "stop_local": "HH:mm", "description": "string", "project_name": "string or null", "tags": ["string"], "billable": true/false/null}],
          "assumptions": ["string"],
          "summary": "string or null"
        }
        """

        let payload: [String: Any] = [
            "model": model,
            "temperature": 0.2,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ]
        ]

        let request = try makeRequest(apiKey: apiKey, payload: payload)
        let data = try await perform(request)
        let text = try extractText(from: data)

        guard let jsonData = text.data(using: .utf8) else {
            throw PlannerServiceError.decoding("OpenAI returned unreadable output.")
        }

        do {
            return try decoder.decode(GeminiExtractionResponse.self, from: jsonData)
        } catch {
            throw PlannerServiceError.decoding("OpenAI returned JSON that did not match the expected schema.")
        }
    }

    func testConnection(apiKey: String, model: String) async throws -> String {
        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 64,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": "Respond with JSON only."],
                ["role": "user", "content": "Return exactly: {\"status\":\"ok\"}"]
            ]
        ]

        let request = try makeRequest(apiKey: apiKey, payload: payload)
        let data = try await perform(request)
        let text = try extractText(from: data)

        if text.contains("ok") {
            return "ok"
        }
        return text
    }

    func polishUserContext(apiKey: String, model: String, rawText: String) async throws -> String {
        let systemPrompt = """
        You help users describe themselves and their work patterns for a time-tracking app called Planner. \
        The app feeds this description into an LLM to better predict and structure daily time entries.

        Your job:
        1. Take the user's raw text about themselves and polish it into a clear, structured description \
        that will help an LLM make better time entry predictions.
        2. If important information is missing, append questions directly in the text (prefixed with "Q: ") \
        so the user can answer them and run the polish again.

        Important details to capture (if not already present):
        - Typical working hours (start time, end time, breaks)
        - Type of work (engineering, design, management, consulting, etc.)
        - Common projects or clients
        - Recurring meetings or activities
        - Preferred time block lengths
        - Billable vs non-billable work patterns

        Keep the tone professional but friendly. Write in first person from the user's perspective.
        Respond with ONLY a JSON object: {"polished_text": "..."}
        """

        let payload: [String: Any] = [
            "model": model,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "Polish this user description for time-tracking context:\n\n\(rawText)"]
            ]
        ]

        let request = try makeRequest(apiKey: apiKey, payload: payload)
        let data = try await perform(request)
        let text = try extractText(from: data)

        if let jsonData = text.data(using: .utf8),
           let parsed = try? decoder.decode(PolishPayload.self, from: jsonData) {
            return parsed.polishedText
        }

        return text
    }

    // MARK: - Private

    private func makeRequest(apiKey: String, payload: [String: Any]) throws -> URLRequest {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw PlannerServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return request
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await httpClient.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlannerServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown OpenAI error"
            throw PlannerServiceError.api(statusCode: httpResponse.statusCode, message: message)
        }

        return data
    }

    private func extractText(from data: Data) throws -> String {
        let response = try decoder.decode(OpenAIResponse.self, from: data)

        guard let choice = response.choices.first,
              let text = choice.message.content, !text.isEmpty else {
            throw PlannerServiceError.emptyResponse("OpenAI returned no content.")
        }

        return text.trimmed
    }
}

private struct OpenAIResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }
        let message: Message
    }

    let choices: [Choice]
}

private struct PolishPayload: Decodable {
    let polishedText: String

    enum CodingKeys: String, CodingKey {
        case polishedText = "polished_text"
    }
}
