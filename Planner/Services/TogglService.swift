import Foundation

protocol TogglServicing {
    func fetchCurrentUser(apiToken: String) async throws -> TogglCurrentUserDTO
    func fetchWorkspaces(apiToken: String) async throws -> [WorkspaceSummary]
    func fetchProjects(apiToken: String, workspaceID: Int) async throws -> [ProjectSummary]
    func createTimeEntries(
        _ submissions: [StoredTimeEntryRecord.TogglSubmission],
        apiToken: String
    ) async throws -> [TogglCreatedTimeEntryDTO]
}

struct TogglService: TogglServicing {
    private let httpClient: HTTPClient
    private let decoder: JSONDecoder

    init(httpClient: HTTPClient, decoder: JSONDecoder = JSONDecoder()) {
        self.httpClient = httpClient
        self.decoder = decoder
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func fetchCurrentUser(apiToken: String) async throws -> TogglCurrentUserDTO {
        try await perform(TogglRequestFactory.makeCurrentUserRequest(apiToken: apiToken))
    }

    func fetchWorkspaces(apiToken: String) async throws -> [WorkspaceSummary] {
        let workspaces: [TogglWorkspaceDTO] = try await perform(TogglRequestFactory.makeWorkspacesRequest(apiToken: apiToken))
        return workspaces.map { WorkspaceSummary(id: $0.id, name: $0.name) }
    }

    func fetchProjects(apiToken: String, workspaceID: Int) async throws -> [ProjectSummary] {
        let projects: [TogglProjectDTO] = try await perform(TogglRequestFactory.makeProjectsRequest(apiToken: apiToken, workspaceID: workspaceID))
        return projects.map { ProjectSummary(id: $0.id, name: $0.name, workspaceId: $0.workspaceId) }
    }

    func createTimeEntries(
        _ submissions: [StoredTimeEntryRecord.TogglSubmission],
        apiToken: String
    ) async throws -> [TogglCreatedTimeEntryDTO] {
        var createdEntries: [TogglCreatedTimeEntryDTO] = []

        for submission in submissions {
            do {
                let request = try TogglRequestFactory.makeCreateTimeEntryRequest(
                    apiToken: apiToken,
                    workspaceID: submission.workspaceID,
                    payload: submission.request
                )
                let created: TogglCreatedTimeEntryDTO = try await perform(request, expectedStatusCodes: 200..<300)
                createdEntries.append(created)
            } catch {
                throw PlannerServiceError.partialSubmission(
                    createdCount: createdEntries.count,
                    totalCount: submissions.count,
                    message: error.localizedDescription
                )
            }
        }

        return createdEntries
    }

    private func perform<T: Decodable>(
        _ request: URLRequest,
        expectedStatusCodes: Range<Int> = 200..<300
    ) async throws -> T {
        let (data, response) = try await httpClient.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlannerServiceError.invalidResponse
        }

        guard expectedStatusCodes.contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown Toggl error"
            throw PlannerServiceError.api(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw PlannerServiceError.decoding("Could not decode the Toggl response.")
        }
    }
}
