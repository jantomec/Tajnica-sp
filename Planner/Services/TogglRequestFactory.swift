import Foundation

enum TogglRequestFactory {
    private static let baseURL = URL(string: "https://api.track.toggl.com/api/v9")!

    static func makeCurrentUserRequest(apiToken: String) -> URLRequest {
        makeRequest(path: "/me", method: "GET", apiToken: apiToken)
    }

    static func makeWorkspacesRequest(apiToken: String) -> URLRequest {
        makeRequest(path: "/me/workspaces", method: "GET", apiToken: apiToken)
    }

    static func makeProjectsRequest(apiToken: String, workspaceID: Int) -> URLRequest {
        makeRequest(path: "/workspaces/\(workspaceID)/projects", method: "GET", apiToken: apiToken)
    }

    static func makeCreateTimeEntryRequest(
        apiToken: String,
        workspaceID: Int,
        payload: TogglTimeEntryCreateRequest
    ) throws -> URLRequest {
        var request = makeRequest(
            path: "/workspaces/\(workspaceID)/time_entries",
            method: "POST",
            apiToken: apiToken
        )
        request.httpBody = try JSONEncoder().encode(payload)
        return request
    }

    private static func makeRequest(path: String, method: String, apiToken: String) -> URLRequest {
        let url = baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        let credentials = Data("\(apiToken):api_token".utf8).base64EncodedString()

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        return request
    }
}
