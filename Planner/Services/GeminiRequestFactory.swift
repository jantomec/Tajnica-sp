import Foundation

enum GeminiRequestFactory {
    private static let endpointBase = "https://generativelanguage.googleapis.com/v1beta/models"

    static func makeExtractionRequest(
        apiKey: String,
        model: String,
        selectedDate: Date,
        timeZone: TimeZone,
        note: String,
        userContext: String? = nil,
        availableProjects: [String] = []
    ) throws -> URLRequest {
        let isoDate = PlannerFormatters.isoLocalDateString(selectedDate, timeZone: timeZone)
        var prompt = """
        Today's date is \(isoDate).
        Local timezone: \(timeZone.identifier)

        User note:
        \(note)
        """

        if let context = userContext?.trimmed, !context.isEmpty {
            prompt += "\n\nUser context (use this to better understand the user's work patterns):\n\(context)"
        }

        if !availableProjects.isEmpty {
            let list = availableProjects.map { "- \($0)" }.joined(separator: "\n")
            prompt += "\n\nAvailable Toggl projects (use the exact name in \"project_name\" when an entry clearly belongs to one; otherwise leave it null):\n\(list)"
        }

        let systemInstruction = """
        Convert the user's note into candidate Toggl time entries.
        Determine the correct date for each entry from the note content. \
        If the note says "yesterday" or references a past day, use that day's date (YYYY-MM-DD). \
        If no specific day is mentioned, default to today's date.
        Each entry MUST include a "date_local" field in YYYY-MM-DD format.
        Infer reasonable contiguous time blocks.
        Do not fabricate high-confidence details that are not supported by the note.
        Keep descriptions concise and suitable for Toggl Track.
        If user context is provided, use it to make better inferences about working hours, typical activities, and project assignments.
        Use only the requested JSON schema output.
        """

        return try makeRequest(
            apiKey: apiKey,
            model: model,
            systemInstruction: systemInstruction,
            prompt: prompt,
            responseSchema: extractionResponseSchema()
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

    private static func extractionResponseSchema() -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "entries": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "date_local": ["type": "string"],
                            "start_local": ["type": "string"],
                            "stop_local": ["type": "string"],
                            "description": ["type": "string"],
                            "project_name": ["type": ["string", "null"]],
                            "tags": [
                                "type": "array",
                                "items": ["type": "string"]
                            ],
                            "billable": ["type": ["boolean", "null"]]
                        ],
                        "required": [
                            "date_local",
                            "start_local",
                            "stop_local",
                            "description",
                            "project_name",
                            "tags",
                            "billable"
                        ]
                    ]
                ],
                "assumptions": [
                    "type": "array",
                    "items": ["type": "string"]
                ],
                "summary": ["type": ["string", "null"]]
            ],
            "required": ["entries", "assumptions", "summary"]
        ]
    }
}
