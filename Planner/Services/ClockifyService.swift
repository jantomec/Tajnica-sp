import Foundation

protocol ClockifyServicing {
    func fetchCurrentUser(apiKey: String) async throws -> ClockifyCurrentUserDTO
    func fetchWorkspaces(apiKey: String) async throws -> [ClockifyWorkspaceSummary]
    func fetchProjects(apiKey: String, workspaceID: String) async throws -> [ClockifyProjectSummary]
    func createTimeEntries(
        _ submissions: [StoredTimeEntryRecord.ClockifySubmission],
        apiKey: String
    ) async throws -> [ClockifyCreatedTimeEntryDTO]
}

struct ClockifyService: ClockifyServicing {
    private let httpClient: HTTPClient
    private let decoder: JSONDecoder

    init(httpClient: HTTPClient, decoder: JSONDecoder = JSONDecoder()) {
        self.httpClient = httpClient
        self.decoder = decoder
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func fetchCurrentUser(apiKey: String) async throws -> ClockifyCurrentUserDTO {
        try await perform(ClockifyRequestFactory.makeCurrentUserRequest(apiKey: apiKey))
    }

    func fetchWorkspaces(apiKey: String) async throws -> [ClockifyWorkspaceSummary] {
        let workspaces: [ClockifyWorkspaceDTO] = try await perform(
            ClockifyRequestFactory.makeWorkspacesRequest(apiKey: apiKey)
        )
        return workspaces.map { ClockifyWorkspaceSummary(id: $0.id, name: $0.name) }
    }

    func fetchProjects(apiKey: String, workspaceID: String) async throws -> [ClockifyProjectSummary] {
        let projects: [ClockifyProjectDTO] = try await perform(
            ClockifyRequestFactory.makeProjectsRequest(apiKey: apiKey, workspaceID: workspaceID)
        )
        return projects.map { ClockifyProjectSummary(id: $0.id, name: $0.name, workspaceId: workspaceID) }
    }

    func createTimeEntries(
        _ submissions: [StoredTimeEntryRecord.ClockifySubmission],
        apiKey: String
    ) async throws -> [ClockifyCreatedTimeEntryDTO] {
        var createdEntries: [ClockifyCreatedTimeEntryDTO] = []

        for submission in submissions {
            do {
                let request = try ClockifyRequestFactory.makeCreateTimeEntryRequest(
                    apiKey: apiKey,
                    workspaceID: submission.workspaceID,
                    payload: submission.request
                )
                let created: ClockifyCreatedTimeEntryDTO = try await perform(
                    request,
                    expectedStatusCodes: 200..<300
                )
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
            let message = String(data: data, encoding: .utf8) ?? "Unknown Clockify error"
            throw PlannerServiceError.api(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw PlannerServiceError.decoding("Could not decode the Clockify response.")
        }
    }
}
