import Foundation
import Testing

@testable import Tajnica_sp

struct OpenAIServiceTests {
    @Test
    func retriesTransient429DuringConnectionTest() async throws {
        let client = HTTPClientStub(results: [
            .success((
                Data(#"{"error":{"message":"rate_limit","type":"rate_limit_error"}}"#.utf8),
                makeResponse(statusCode: 429)
            )),
            .success((
                Data(#"""
                {"id":"c_1","object":"chat.completion","choices":[{"message":{"role":"assistant","content":"{\"status\":\"ok\"}"}}]}
                """#.utf8),
                makeResponse(statusCode: 200)
            ))
        ])
        let service = OpenAIService(httpClient: client, retryPolicy: .fixed([0]))

        let status = try await service.testConnection(apiKey: "demo-key", model: "gpt-4o")

        #expect(status == "ok")
        #expect(await client.requestCount() == 2)
    }

    @Test
    func surfaces5xxAfterRetriesAreExhausted() async {
        let client = HTTPClientStub(results: [
            .success((
                Data(#"{"error":{"message":"bad gateway"}}"#.utf8),
                makeResponse(statusCode: 502)
            )),
            .success((
                Data(#"{"error":{"message":"still bad gateway"}}"#.utf8),
                makeResponse(statusCode: 502)
            ))
        ])
        let service = OpenAIService(httpClient: client, retryPolicy: .fixed([0]))

        do {
            _ = try await service.testConnection(apiKey: "demo-key", model: "gpt-4o")
            Issue.record("Expected OpenAI test connection to fail after retry exhaustion.")
        } catch let error as PlannerServiceError {
            guard case let .api(statusCode, message) = error else {
                Issue.record("Expected API error, got \(error).")
                return
            }

            #expect(statusCode == 502)
            #expect(message.contains("still bad gateway"))
            #expect(await client.requestCount() == 2)
        } catch {
            Issue.record("Expected PlannerServiceError, got \(error).")
        }
    }

    @Test
    func extractionDecodesStrictJsonSchemaPayload() async throws {
        let responseBody = #"""
        {
          "id":"c_1","object":"chat.completion",
          "choices":[{
            "message":{
              "role":"assistant",
              "content":"{\"entries\":[{\"date_local\":\"2026-04-23\",\"start_local\":\"09:00\",\"stop_local\":\"10:00\",\"description\":\"Client standup\",\"toggl_workspace_name\":null,\"toggl_project_name\":null,\"clockify_workspace_name\":null,\"clockify_project_name\":null,\"harvest_account_name\":null,\"harvest_project_name\":null,\"harvest_task_name\":null,\"tags\":[\"standup\"],\"billable\":true}],\"assumptions\":[],\"summary\":\"One meeting\"}"
            }
          }]
        }
        """#
        let client = HTTPClientStub(results: [
            .success((Data(responseBody.utf8), makeResponse(statusCode: 200)))
        ])
        let service = OpenAIService(httpClient: client, retryPolicy: .disabled)

        let note = DailyNoteInput(date: TestSupport.selectedDay(), rawText: "Client standup 9–10.")
        let response = try await service.extractTimeEntries(
            apiKey: "demo-key",
            model: "gpt-4o",
            note: note,
            timeZone: TestSupport.timeZone,
            extractionContext: LLMExtractionContext(
                userContext: nil,
                togglWorkspaces: [],
                clockifyWorkspaces: [],
                harvestAccounts: []
            )
        )

        #expect(response.entries.count == 1)
        #expect(response.entries.first?.description == "Client standup")
        #expect(response.entries.first?.billable == true)
        #expect(response.summary == "One meeting")
    }

    @Test
    func refusalSurfacesEmptyResponseError() async {
        let responseBody = #"""
        {"id":"c_1","object":"chat.completion","choices":[{"message":{"role":"assistant","content":null,"refusal":"I cannot comply."}}]}
        """#
        let client = HTTPClientStub(results: [
            .success((Data(responseBody.utf8), makeResponse(statusCode: 200)))
        ])
        let service = OpenAIService(httpClient: client, retryPolicy: .disabled)

        do {
            _ = try await service.testConnection(apiKey: "demo-key", model: "gpt-4o")
            Issue.record("Expected OpenAI refusal to surface as emptyResponse.")
        } catch let error as PlannerServiceError {
            if case let .emptyResponse(message) = error, message.contains("refused") {
                return
            }
            Issue.record("Expected refusal emptyResponse, got \(error).")
        } catch {
            Issue.record("Expected PlannerServiceError, got \(error).")
        }
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
        url: URL(string: "https://api.openai.com/v1/chat/completions")!,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
    )!
}
