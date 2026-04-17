import Foundation

/// Gemini-specific LLM service. Inherits all requirements from LLMServicing.
protocol GeminiServicing: LLMServicing {}

struct GeminiService: GeminiServicing {
    private let httpClient: HTTPClient
    private let decoder: JSONDecoder
    private let retryDelaysNanoseconds: [UInt64]

    init(
        httpClient: HTTPClient,
        decoder: JSONDecoder = JSONDecoder(),
        retryDelaysNanoseconds: [UInt64] = [300_000_000, 900_000_000]
    ) {
        self.httpClient = httpClient
        self.decoder = decoder
        self.retryDelaysNanoseconds = retryDelaysNanoseconds
    }

    func extractTimeEntries(
        apiKey: String,
        model: String,
        note: DailyNoteInput,
        timeZone: TimeZone,
        extractionContext: LLMExtractionContext
    ) async throws -> GeminiExtractionResponse {
        let request = try GeminiRequestFactory.makeExtractionRequest(
            apiKey: apiKey,
            model: model,
            selectedDate: note.date,
            timeZone: timeZone,
            note: note.rawText,
            extractionContext: extractionContext
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
        var attempt = 0

        while true {
            do {
                let (data, response) = try await httpClient.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw PlannerServiceError.invalidResponse
                }

                guard (200..<300).contains(httpResponse.statusCode) else {
                    let message = String(data: data, encoding: .utf8) ?? "Unknown Gemini error"
                    let error = PlannerServiceError.api(statusCode: httpResponse.statusCode, message: message)

                    guard shouldRetry(after: error, attempt: attempt) else {
                        throw error
                    }

                    try await Task.sleep(nanoseconds: retryDelaysNanoseconds[attempt])
                    attempt += 1
                    continue
                }

                return data
            } catch {
                guard shouldRetry(after: error, attempt: attempt) else {
                    throw error
                }

                try await Task.sleep(nanoseconds: retryDelaysNanoseconds[attempt])
                attempt += 1
            }
        }
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

    private func shouldRetry(after error: Error, attempt: Int) -> Bool {
        guard attempt < retryDelaysNanoseconds.count else {
            return false
        }

        if case let PlannerServiceError.api(statusCode, _) = error {
            return [429, 500, 502, 503, 504].contains(statusCode)
        }

        if let urlError = error as? URLError {
            return [
                .timedOut,
                .cannotFindHost,
                .cannotConnectToHost,
                .dnsLookupFailed,
                .networkConnectionLost,
                .notConnectedToInternet
            ].contains(urlError.code)
        }

        return false
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
