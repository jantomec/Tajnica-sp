import Foundation

/// Gemini-specific LLM service. Inherits all requirements from LLMServicing.
protocol GeminiServicing: LLMServicing {}

struct GeminiService: GeminiServicing {
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
        userContext: String?
    ) async throws -> GeminiExtractionResponse {
        let request = try GeminiRequestFactory.makeExtractionRequest(
            apiKey: apiKey,
            model: model,
            selectedDate: note.date,
            timeZone: timeZone,
            note: note.rawText,
            userContext: userContext
        )

        let data = try await perform(request)
        let text = try extractText(from: data)

        guard let jsonData = text.data(using: .utf8) else {
            throw PlannerServiceError.decoding("Gemini returned unreadable structured output.")
        }

        do {
            return try decoder.decode(GeminiExtractionResponse.self, from: jsonData)
        } catch {
            throw PlannerServiceError.decoding("Gemini returned JSON that did not match the expected schema.")
        }
    }

    func testConnection(apiKey: String, model: String) async throws -> String {
        let request = try GeminiRequestFactory.makeConnectionTestRequest(apiKey: apiKey, model: model)
        let data = try await perform(request)
        let text = try extractText(from: data)
        guard let jsonData = text.data(using: .utf8) else {
            throw PlannerServiceError.decoding("Gemini returned unreadable test output.")
        }

        let payload = try decoder.decode(GeminiConnectionPayload.self, from: jsonData)
        return payload.status
    }

    func polishUserContext(apiKey: String, model: String, rawText: String) async throws -> String {
        let request = try GeminiRequestFactory.makePolishUserContextRequest(
            apiKey: apiKey,
            model: model,
            rawText: rawText
        )
        let data = try await perform(request)
        let text = try extractText(from: data)

        guard let jsonData = text.data(using: .utf8) else {
            throw PlannerServiceError.decoding("Gemini returned unreadable output.")
        }

        let payload = try decoder.decode(PolishContextPayload.self, from: jsonData)
        return payload.polished_text
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await httpClient.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlannerServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown Gemini error"
            throw PlannerServiceError.api(statusCode: httpResponse.statusCode, message: message)
        }

        return data
    }

    private func extractText(from data: Data) throws -> String {
        let response = try decoder.decode(GeminiGenerateContentResponse.self, from: data)

        if let part = response.candidates.first?.content?.parts.first(where: { $0.text?.isEmpty == false }),
           let text = part.text {
            return text
        }

        if let reason = response.promptFeedback?.blockReason {
            throw PlannerServiceError.emptyResponse("Gemini blocked the request: \(reason).")
        }

        throw PlannerServiceError.emptyResponse("Gemini returned no structured content.")
    }
}

private struct GeminiConnectionPayload: Decodable {
    let status: String
}

private struct PolishContextPayload: Decodable {
    let polished_text: String
}

private struct GeminiGenerateContentResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String?
            }

            let parts: [Part]
        }

        let content: Content?
    }

    struct PromptFeedback: Decodable {
        let blockReason: String?
    }

    let candidates: [Candidate]
    let promptFeedback: PromptFeedback?
}
