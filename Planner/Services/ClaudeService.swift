import Foundation

struct ClaudeService: LLMServicing {
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
        extractionContext: LLMExtractionContext
    ) async throws -> GeminiExtractionResponse {
        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": """
            \(LLMExtractionPromptBuilder.systemInstruction)

            You MUST respond with ONLY a valid JSON object (no markdown, no code blocks) matching this schema:
            \(LLMExtractionPromptBuilder.jsonSchemaSummary)
            """,
            "messages": [
                [
                    "role": "user",
                    "content": LLMExtractionPromptBuilder.makeUserPrompt(
                        selectedDate: note.date,
                        timeZone: timeZone,
                        note: note.rawText,
                        context: extractionContext
                    )
                ]
            ]
        ]

        let request = try makeRequest(apiKey: apiKey, payload: payload)
        let data = try await perform(request)
        let text = try extractText(from: data)

        guard let jsonData = text.data(using: .utf8) else {
            throw PlannerServiceError.decoding("Claude returned unreadable output.")
        }

        do {
            return try decoder.decode(GeminiExtractionResponse.self, from: jsonData)
        } catch {
            throw PlannerServiceError.decoding("Claude returned JSON that did not match the expected schema.")
        }
    }

    func testConnection(apiKey: String, model: String) async throws -> String {
        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 256,
            "messages": [
                ["role": "user", "content": "Return exactly this JSON and nothing else: {\"status\":\"ok\"}"]
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
        You help users describe themselves and their work patterns for a time-tracking app called \(AppConfiguration.displayName). \
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
            "max_tokens": 2048,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": "Polish this user description for time-tracking context:\n\n\(rawText)"]
            ]
        ]

        let request = try makeRequest(apiKey: apiKey, payload: payload)
        let data = try await perform(request)
        let text = try extractText(from: data)

        // Try to parse as JSON first
        if let jsonData = text.data(using: .utf8),
           let parsed = try? decoder.decode(PolishPayload.self, from: jsonData) {
            return parsed.polishedText
        }

        // Fall back to raw text if not JSON
        return text
    }

    // MARK: - Private

    private func makeRequest(apiKey: String, payload: [String: Any]) throws -> URLRequest {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw PlannerServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return request
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await httpClient.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlannerServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown Claude error"
            throw PlannerServiceError.api(statusCode: httpResponse.statusCode, message: message)
        }

        return data
    }

    private func extractText(from data: Data) throws -> String {
        let response = try decoder.decode(ClaudeResponse.self, from: data)

        guard let textBlock = response.content.first(where: { $0.type == "text" }),
              let text = textBlock.text, !text.isEmpty else {
            throw PlannerServiceError.emptyResponse("Claude returned no content.")
        }

        // Strip markdown code fences if present
        var cleaned = text.trimmed
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }

        return cleaned.trimmed
    }
}

private struct ClaudeResponse: Decodable {
    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }

    let content: [ContentBlock]
}

private struct PolishPayload: Decodable {
    let polishedText: String

    enum CodingKeys: String, CodingKey {
        case polishedText = "polished_text"
    }
}
