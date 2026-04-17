import Foundation
import Testing

@testable import Tajnica_sp

struct GeminiServiceTests {
    @Test
    func retriesTransient503DuringConnectionTest() async throws {
        let client = HTTPClientStub(results: [
            .success((
                Data(#"{"error":{"code":503,"message":"backend busy","status":"UNAVAILABLE"}}"#.utf8),
                makeResponse(statusCode: 503)
            )),
            .success((
                Data(#"{"candidates":[{"content":{"parts":[{"text":"{\"status\":\"ok\"}"}]}}]}"#.utf8),
                makeResponse(statusCode: 200)
            ))
        ])
        let service = GeminiService(httpClient: client, retryDelaysNanoseconds: [0])

        let status = try await service.testConnection(apiKey: "demo-key", model: "gemini-2.5-flash")

        #expect(status == "ok")
        #expect(await client.requestCount() == 2)
    }

    @Test
    func surfaces503AfterRetriesAreExhausted() async {
        let client = HTTPClientStub(results: [
            .success((
                Data(#"{"error":{"code":503,"message":"backend busy","status":"UNAVAILABLE"}}"#.utf8),
                makeResponse(statusCode: 503)
            )),
            .success((
                Data(#"{"error":{"code":503,"message":"backend still busy","status":"UNAVAILABLE"}}"#.utf8),
                makeResponse(statusCode: 503)
            ))
        ])
        let service = GeminiService(httpClient: client, retryDelaysNanoseconds: [0])

        do {
            _ = try await service.testConnection(apiKey: "demo-key", model: "gemini-2.5-flash")
            Issue.record("Expected Gemini test connection to fail after retry exhaustion.")
        } catch let error as PlannerServiceError {
            guard case let .api(statusCode, message) = error else {
                Issue.record("Expected API error, got \(error).")
                return
            }

            #expect(statusCode == 503)
            #expect(message.contains("backend still busy"))
            #expect(await client.requestCount() == 2)
        } catch {
            Issue.record("Expected PlannerServiceError, got \(error).")
        }
    }

    @Test
    func describes503AsTemporaryServiceIssue() {
        let message = PlannerServiceError.api(statusCode: 503, message: "backend busy").localizedDescription

        #expect(message.contains("temporarily unavailable"))
        #expect(message.contains("503"))
    }
}

private actor HTTPClientStub: HTTPClient {
    private var results: [Result<(Data, URLResponse), Error>]
    private var requests: [URLRequest] = []

    init(results: [Result<(Data, URLResponse), Error>]) {
        self.results = results
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        guard !results.isEmpty else {
            throw URLError(.badServerResponse)
        }
        return try results.removeFirst().get()
    }

    func requestCount() -> Int {
        requests.count
    }
}

private func makeResponse(statusCode: Int) -> HTTPURLResponse {
    HTTPURLResponse(
        url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent")!,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
    )!
}
