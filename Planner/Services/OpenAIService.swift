import Foundation

struct OpenAIService: LLMServicing {
    private let httpClient: HTTPClient
    private let decoder: JSONDecoder
    private let retryPolicy: LLMRetryPolicy

    init(
        httpClient: HTTPClient,
        decoder: JSONDecoder = JSONDecoder(),
        retryPolicy: LLMRetryPolicy = LLMRetryPolicy()
    ) {
        self.httpClient = httpClient
        self.decoder = decoder
        self.retryPolicy = retryPolicy
    }

    func extractTimeEntries(
        apiKey: String,
        model: String,
        note: DailyNoteInput,
        timeZone: TimeZone,
        extractionContext: LLMExtractionContext
    ) async throws -> GeminiExtractionResponse {
        let userPrompt = LLMExtractionPromptBuilder.makeUserPrompt(
            selectedDate: note.date,
            timeZone: timeZone,
            note: note.rawText,
            context: extractionContext
        )

        let payload: [String: Any] = [
            "model": model,
            "temperature": 0.2,
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": "planner_time_entries",
                    "strict": true,
                    "schema": LLMExtractionPromptBuilder.responseSchema(additionalPropertiesDisallowed: true)
                ]
            ],
            "messages": [
                ["role": "system", "content": LLMExtractionPromptBuilder.systemInstruction],
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
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": "planner_connection_status",
                    "strict": true,
                    "schema": [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": [
                            "status": ["type": "string"]
                        ],
                        "required": ["status"]
                    ]
                ]
            ],
            "messages": [
                ["role": "system", "content": "Respond using the configured JSON schema."],
                ["role": "user", "content": "Return status \"ok\"."]
            ]
        ]

        let request = try makeRequest(apiKey: apiKey, payload: payload)
        let data = try await perform(request)
        let text = try extractText(from: data)
        guard let jsonData = text.data(using: .utf8) else {
            throw PlannerServiceError.decoding("OpenAI returned unreadable test output.")
        }

        let payloadResponse = try decoder.decode(ConnectionTestPayload.self, from: jsonData)
        return payloadResponse.status
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
        Return the polished text via the configured JSON schema.
        """

        let payload: [String: Any] = [
            "model": model,
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": "planner_polished_context",
                    "strict": true,
                    "schema": [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": [
                            "polished_text": ["type": "string"]
                        ],
                        "required": ["polished_text"]
                    ]
                ]
            ],
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "Polish this user description for time-tracking context:\n\n\(rawText)"]
            ]
        ]

        let request = try makeRequest(apiKey: apiKey, payload: payload)
        let data = try await perform(request)
        let text = try extractText(from: data)

        guard let jsonData = text.data(using: .utf8) else {
            throw PlannerServiceError.decoding("OpenAI returned unreadable output.")
        }

        let parsed = try decoder.decode(PolishPayload.self, from: jsonData)
        return parsed.polishedText
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
        try await retryPolicy.perform(request, using: httpClient, providerLabel: "OpenAI")
    }

    private func extractText(from data: Data) throws -> String {
        let response = try decoder.decode(OpenAIResponse.self, from: data)

        if let refusal = response.choices.first?.message.refusal, !refusal.isEmpty {
            throw PlannerServiceError.emptyResponse("OpenAI refused the request: \(refusal)")
        }

        guard let text = response.choices.first?.message.content, !text.isEmpty else {
            throw PlannerServiceError.emptyResponse("OpenAI returned no content.")
        }

        return text.trimmed
    }
}

private struct OpenAIResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
            let refusal: String?
        }
        let message: Message
    }

    let choices: [Choice]
}

private struct ConnectionTestPayload: Decodable {
    let status: String
}

private struct PolishPayload: Decodable {
    let polishedText: String

    enum CodingKeys: String, CodingKey {
        case polishedText = "polished_text"
    }
}
