import Foundation

enum ClockifyRequestFactory {
    private static let baseURL = URL(string: "https://api.clockify.me/api/v1")!

    static func makeCurrentUserRequest(apiKey: String) -> URLRequest {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("user"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "include-memberships", value: "true")
        ]
        return makeRequest(
            url: components?.url ?? baseURL.appendingPathComponent("user"),
            method: "GET",
            apiKey: apiKey
        )
    }

    static func makeWorkspacesRequest(apiKey: String) -> URLRequest {
        makeRequest(
            url: baseURL.appendingPathComponent("workspaces"),
            method: "GET",
            apiKey: apiKey
        )
    }

    static func makeProjectsRequest(apiKey: String, workspaceID: String) -> URLRequest {
        makeRequest(
            url: baseURL
                .appendingPathComponent("workspaces")
                .appendingPathComponent(workspaceID)
                .appendingPathComponent("projects"),
            method: "GET",
            apiKey: apiKey
        )
    }

    static func makeCreateTimeEntryRequest(
        apiKey: String,
        workspaceID: String,
        payload: ClockifyTimeEntryCreateRequest
    ) throws -> URLRequest {
        var request = makeRequest(
            url: baseURL
                .appendingPathComponent("workspaces")
                .appendingPathComponent(workspaceID)
                .appendingPathComponent("time-entries"),
            method: "POST",
            apiKey: apiKey
        )
        request.httpBody = try JSONEncoder().encode(payload)
        return request
    }

    private static func makeRequest(url: URL, method: String, apiKey: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        return request
    }
}
