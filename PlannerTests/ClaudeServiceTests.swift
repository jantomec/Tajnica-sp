import Foundation
import Testing

@testable import Tajnica_sp

struct ClaudeServiceTests {
    @Test
    func retriesTransient529DuringConnectionTest() async throws {
        let client = HTTPClientStub(results: [
            .success((
                Data(#"{"type":"error","error":{"type":"overloaded_error","message":"overloaded"}}"#.utf8),
                makeResponse(statusCode: 529)
            )),
            .success((
                Data(#"""
                {"id":"msg_1","type":"message","role":"assistant","model":"claude","content":[{"type":"tool_use","id":"tu_1","name":"report_status","input":{"status":"ok"}}]}
                """#.utf8),
                makeResponse(statusCode: 503)
            )),
            .success((
                Data(#"""
                {"id":"msg_2","type":"message","role":"assistant","model":"claude","content":[{"type":"tool_use","id":"tu_2","name":"report_status","input":{"status":"ok"}}]}
                """#.utf8),
                makeResponse(statusCode: 200)
            ))
        ])
        let service = ClaudeService(httpClient: client, retryPolicy: .fixed([0, 0]))

        let status = try await service.testConnection(apiKey: "demo-key", model: "claude-sonnet")

        #expect(status == "ok")
        #expect(await client.requestCount() == 3)
    }

    @Test
    func surfacesOverloadedAfterRetriesAreExhausted() async {
        let client = HTTPClientStub(results: [
            .success((
                Data(#"{"type":"error","error":{"type":"rate_limit_error","message":"rate limited"}}"#.utf8),
                makeResponse(statusCode: 429)
            )),
            .success((
                Data(#"{"type":"error","error":{"type":"rate_limit_error","message":"still rate limited"}}"#.utf8),
                makeResponse(statusCode: 429)
            ))
        ])
        let service = ClaudeService(httpClient: client, retryPolicy: .fixed([0]))

        do {
            _ = try await service.testConnection(apiKey: "demo-key", model: "claude-sonnet")
            Issue.record("Expected Claude test connection to fail after retry exhaustion.")
        } catch let error as PlannerServiceError {
            guard case let .api(statusCode, message) = error else {
                Issue.record("Expected API error, got \(error).")
                return
            }

            #expect(statusCode == 429)
            #expect(message.contains("still rate limited"))
            #expect(await client.requestCount() == 2)
        } catch {
            Issue.record("Expected PlannerServiceError, got \(error).")
        }
    }

    @Test
    func extractionDecodesToolUseInputIntoResponse() async throws {
        let responseBody = #"""
        {
          "id":"msg_1","type":"message","role":"assistant","model":"claude",
          "content":[
            {"type":"tool_use","id":"tu_1","name":"emit_time_entries","input":{
              "entries":[{
                "date_local":"2026-04-23",
                "start_local":"09:00",
                "stop_local":"10:00",
                "description":"Client standup",
                "toggl_workspace_name":null,
                "toggl_project_name":null,
                "clockify_workspace_name":null,
                "clockify_project_name":null,
                "harvest_account_name":null,
                "harvest_project_name":null,
                "harvest_task_name":null,
                "tags":["standup"],
                "billable":true
              }],
              "assumptions":[],
              "summary":"One meeting"
            }}
          ]
        }
        """#
        let client = HTTPClientStub(results: [
            .success((Data(responseBody.utf8), makeResponse(statusCode: 200)))
        ])
        let service = ClaudeService(httpClient: client, retryPolicy: .disabled)

        let note = DailyNoteInput(date: TestSupport.selectedDay(), rawText: "Client standup 9–10.")
        let response = try await service.extractTimeEntries(
            apiKey: "demo-key",
            model: "claude-sonnet",
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
    func emptyContentSurfacesEmptyResponseError() async {
        let client = HTTPClientStub(results: [
            .success((
                Data(#"{"id":"msg_1","type":"message","role":"assistant","model":"claude","content":[]}"#.utf8),
                makeResponse(statusCode: 200)
            ))
        ])
        let service = ClaudeService(httpClient: client, retryPolicy: .disabled)

        do {
            _ = try await service.testConnection(apiKey: "demo-key", model: "claude-sonnet")
            Issue.record("Expected Claude to surface an empty response error when no tool_use block exists.")
        } catch let error as PlannerServiceError {
            if case .emptyResponse = error {
                return
            }
            Issue.record("Expected emptyResponse, got \(error).")
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
        url: URL(string: "https://api.anthropic.com/v1/messages")!,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
    )!
}
