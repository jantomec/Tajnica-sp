import Foundation
import Testing

@testable import Planner

struct RequestConstructionTests {
    @Test
    func buildsGeminiStructuredOutputRequest() throws {
        let request = try GeminiRequestFactory.makeExtractionRequest(
            apiKey: "demo-key",
            model: "gemini-2.5-flash",
            selectedDate: TestSupport.selectedDay(),
            timeZone: TestSupport.timeZone,
            note: "Worked on release and calls."
        )

        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString.contains("models/gemini-2.5-flash:generateContent") == true)
        #expect(request.url?.query?.contains("key=demo-key") == true)

        let body = try #require(request.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let generationConfig = try #require(json["generationConfig"] as? [String: Any])
        let contents = try #require(json["contents"] as? [[String: Any]])
        let parts = try #require(contents.first?["parts"] as? [[String: Any]])
        let prompt = try #require(parts.first?["text"] as? String)

        #expect(generationConfig["responseMimeType"] as? String == "application/json")
        #expect(generationConfig["responseJsonSchema"] != nil)
        #expect(prompt.contains("Today's date is 2026-04-02."))
        #expect(prompt.contains("Local timezone: Europe/Ljubljana"))
    }

    @Test
    func buildsTogglRequestsWithBasicAuth() throws {
        let workspacesRequest = TogglRequestFactory.makeWorkspacesRequest(apiToken: "secret-token")
        let payload = TogglTimeEntryCreateRequest(
            billable: true,
            createdWith: AppConfiguration.createdWith,
            description: "Write tests",
            duration: 3_600,
            projectId: 7,
            start: "2026-04-02T09:00:00.000Z",
            stop: "2026-04-02T10:00:00.000Z",
            tags: ["tests"],
            workspaceId: 55
        )
        let createRequest = try TogglRequestFactory.makeCreateTimeEntryRequest(
            apiToken: "secret-token",
            workspaceID: 55,
            payload: payload
        )

        let expectedAuthorization = "Basic \(Data("secret-token:api_token".utf8).base64EncodedString())"

        #expect(workspacesRequest.httpMethod == "GET")
        #expect(workspacesRequest.url?.absoluteString == "https://api.track.toggl.com/api/v9/me/workspaces")
        #expect(workspacesRequest.value(forHTTPHeaderField: "Authorization") == expectedAuthorization)

        #expect(createRequest.httpMethod == "POST")
        #expect(createRequest.url?.absoluteString == "https://api.track.toggl.com/api/v9/workspaces/55/time_entries")
        #expect(createRequest.value(forHTTPHeaderField: "Authorization") == expectedAuthorization)

        let body = try #require(createRequest.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])

        #expect(json["created_with"] as? String == AppConfiguration.createdWith)
        #expect(json["workspace_id"] as? Int == 55)
        #expect(json["project_id"] as? Int == 7)
    }
}
