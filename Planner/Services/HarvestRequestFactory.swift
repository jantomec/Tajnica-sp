import Foundation

enum HarvestRequestFactory {
    private static let baseURL = URL(string: "https://api.harvestapp.com/api/v2")!
    private static let identityBaseURL = URL(string: "https://id.getharvest.com/api/v2")!

    static func makeAccountsRequest(accessToken: String) -> URLRequest {
        makeRequest(
            url: identityBaseURL.appendingPathComponent("accounts"),
            method: "GET",
            accessToken: accessToken,
            accountID: nil
        )
    }

    static func makeCurrentUserRequest(accessToken: String, accountID: Int) -> URLRequest {
        makeRequest(
            url: baseURL
                .appendingPathComponent("users")
                .appendingPathComponent("me"),
            method: "GET",
            accessToken: accessToken,
            accountID: accountID
        )
    }

    static func makeProjectAssignmentsRequest(accessToken: String, accountID: Int) -> URLRequest {
        makeRequest(
            url: baseURL
                .appendingPathComponent("users")
                .appendingPathComponent("me")
                .appendingPathComponent("project_assignments"),
            method: "GET",
            accessToken: accessToken,
            accountID: accountID
        )
    }

    static func makeTimestampCreateTimeEntryRequest(
        accessToken: String,
        accountID: Int,
        projectID: Int,
        taskID: Int,
        entry: CandidateTimeEntry
    ) throws -> URLRequest {
        let payload = HarvestTimestampTimeEntryCreateRequest.make(
            from: entry,
            projectID: projectID,
            taskID: taskID
        )
        return try makeCreateTimeEntryRequest(
            accessToken: accessToken,
            accountID: accountID,
            payload: payload
        )
    }

    static func makeDurationCreateTimeEntryRequest(
        accessToken: String,
        accountID: Int,
        projectID: Int,
        taskID: Int,
        entry: CandidateTimeEntry
    ) throws -> URLRequest {
        let payload = HarvestDurationTimeEntryCreateRequest.make(
            from: entry,
            projectID: projectID,
            taskID: taskID
        )
        return try makeCreateTimeEntryRequest(
            accessToken: accessToken,
            accountID: accountID,
            payload: payload
        )
    }

    static func makeCreateTimeEntryRequest<T: Encodable>(
        accessToken: String,
        accountID: Int,
        payload: T
    ) throws -> URLRequest {
        var request = makeRequest(
            url: baseURL.appendingPathComponent("time_entries"),
            method: "POST",
            accessToken: accessToken,
            accountID: accountID
        )
        request.httpBody = try JSONEncoder().encode(payload)
        return request
    }

    private static func makeRequest(
        url: URL,
        method: String,
        accessToken: String,
        accountID: Int?
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(
            "\(AppConfiguration.displayName) (\(Bundle.main.bundleIdentifier ?? "Planner"))",
            forHTTPHeaderField: "User-Agent"
        )

        if let accountID {
            request.setValue(String(accountID), forHTTPHeaderField: "Harvest-Account-ID")
        }

        return request
    }
}
