import Foundation

enum GeminiRequestFactory {
    private static let endpointBase = "https://generativelanguage.googleapis.com/v1beta/models"

    static func makeExtractionRequest(
        apiKey: String,
        model: String,
        selectedDate: Date,
        timeZone: TimeZone,
        note: String,
        extractionContext: LLMExtractionContext
    ) throws -> URLRequest {
        return try makeRequest(
            apiKey: apiKey,
            model: model,
            systemInstruction: LLMExtractionPromptBuilder.systemInstruction,
            prompt: LLMExtractionPromptBuilder.makeUserPrompt(
                selectedDate: selectedDate,
                timeZone: timeZone,
                note: note,
                context: extractionContext
            ),
            responseSchema: LLMExtractionPromptBuilder.responseSchema()
        )
    }

    static func makeConnectionTestRequest(apiKey: String, model: String) throws -> URLRequest {
        try makeRequest(
            apiKey: apiKey,
            model: model,
            systemInstruction: "Return a small JSON object that confirms the API is reachable.",
            prompt: "Return {\"status\":\"ok\"}.",
            responseSchema: [
                "type": "object",
                "properties": [
                    "status": [
                        "type": "string"
                    ]
                ],
                "required": ["status"]
            ]
        )
    }

    static func makePolishUserContextRequest(
        apiKey: String,
        model: String,
        rawText: String
    ) throws -> URLRequest {
        let systemInstruction = """
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

        Return a single JSON object with a "polished_text" field containing the result.
        Keep the tone professional but friendly. Write in first person from the user's perspective.
        """

        return try makeRequest(
            apiKey: apiKey,
            model: model,
            systemInstruction: systemInstruction,
            prompt: "Polish this user description for time-tracking context:\n\n\(rawText)",
            responseSchema: [
                "type": "object",
                "properties": [
                    "polished_text": ["type": "string"]
                ],
                "required": ["polished_text"]
            ]
        )
    }

    private static func makeRequest(
        apiKey: String,
        model: String,
        systemInstruction: String,
        prompt: String,
        responseSchema: [String: Any]
    ) throws -> URLRequest {
        guard var components = URLComponents(string: "\(endpointBase)/\(model):generateContent") else {
            throw PlannerServiceError.invalidResponse
        }

        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey)
        ]

        guard let url = components.url else {
            throw PlannerServiceError.invalidResponse
        }

        let payload: [String: Any] = [
            "systemInstruction": [
                "parts": [
                    ["text": systemInstruction]
                ]
            ],
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.2,
                "responseMimeType": "application/json",
                "responseJsonSchema": responseSchema
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return request
    }
}
