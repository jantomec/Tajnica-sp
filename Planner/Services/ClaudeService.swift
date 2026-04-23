import Foundation

struct ClaudeService: LLMServicing {
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
            "max_tokens": 4096,
            "system": LLMExtractionPromptBuilder.systemInstruction,
            "tools": [
                [
                    "name": Self.extractionToolName,
                    "description": "Produces candidate time entries for \(AppConfiguration.displayName).",
                    "input_schema": LLMExtractionPromptBuilder.responseSchema()
                ]
            ],
            "tool_choice": ["type": "tool", "name": Self.extractionToolName],
            "messages": [
                ["role": "user", "content": userPrompt]
            ]
        ]

        let request = try makeRequest(apiKey: apiKey, payload: payload)
        let data = try await perform(request)
        return try decodeToolInput(GeminiExtractionResponse.self, from: data)
    }

    func testConnection(apiKey: String, model: String) async throws -> String {
        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 256,
            "system": "Return a tiny JSON status via the supplied tool.",
            "tools": [
                [
                    "name": Self.connectionToolName,
                    "description": "Reports that the Claude API is reachable.",
                    "input_schema": [
                        "type": "object",
                        "properties": [
                            "status": ["type": "string"]
                        ],
                        "required": ["status"]
                    ]
                ]
            ],
            "tool_choice": ["type": "tool", "name": Self.connectionToolName],
            "messages": [
                ["role": "user", "content": "Use the tool to report {\"status\":\"ok\"}."]
            ]
        ]

        let request = try makeRequest(apiKey: apiKey, payload: payload)
        let data = try await perform(request)
        let payloadResponse = try decodeToolInput(ConnectionTestPayload.self, from: data)
        return payloadResponse.status
    }

    func polishUserContext(apiKey: String, model: String, rawText: String) async throws -> String {
        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": Self.polishSystemInstruction,
            "tools": [
                [
                    "name": Self.polishToolName,
                    "description": "Returns a polished user-context description.",
                    "input_schema": [
                        "type": "object",
                        "properties": [
                            "polished_text": ["type": "string"]
                        ],
                        "required": ["polished_text"]
                    ]
                ]
            ],
            "tool_choice": ["type": "tool", "name": Self.polishToolName],
            "messages": [
                ["role": "user", "content": "Polish this user description for time-tracking context:\n\n\(rawText)"]
            ]
        ]

        let request = try makeRequest(apiKey: apiKey, payload: payload)
        let data = try await perform(request)
        let parsed = try decodeToolInput(PolishPayload.self, from: data)
        return parsed.polishedText
    }

    // MARK: - Private

    private static let extractionToolName = "emit_time_entries"
    private static let connectionToolName = "report_status"
    private static let polishToolName = "emit_polished_context"

    private static let polishSystemInstruction = """
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
    Return the polished text via the supplied tool only.
    """

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
        try await retryPolicy.perform(request, using: httpClient, providerLabel: "Claude")
    }

    /// Decodes the `input` of the first `tool_use` content block directly as
    /// the caller's `Input` type. Claude's forced `tool_choice` guarantees the
    /// block matches the declared `input_schema`, so this is the native
    /// structured-output path for the Messages API.
    private func decodeToolInput<Input: Decodable>(_: Input.Type, from data: Data) throws -> Input {
        let response: ClaudeToolResponse<Input>
        do {
            response = try decoder.decode(ClaudeToolResponse<Input>.self, from: data)
        } catch {
            throw PlannerServiceError.decoding("Claude returned JSON that did not match the expected schema.")
        }

        guard let toolInput = response.content.first(where: { $0.type == "tool_use" })?.input else {
            throw PlannerServiceError.emptyResponse("Claude returned no tool output.")
        }
        return toolInput
    }
}

/// Generic wrapper for Claude's Messages response when the caller expects a
/// `tool_use` content block. `input` is declared optional so text blocks (which
/// omit the field entirely) decode cleanly alongside the tool-use block.
private struct ClaudeToolResponse<Input: Decodable>: Decodable {
    struct ContentBlock: Decodable {
        let type: String
        let input: Input?
    }

    let content: [ContentBlock]
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
