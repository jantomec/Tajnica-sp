import Foundation

protocol HarvestServicing {
    func fetchAccounts(accessToken: String) async throws -> [HarvestAccountSummary]
    func fetchCurrentUser(accessToken: String, accountID: Int) async throws -> HarvestCurrentUserDTO
    func fetchProjectAssignments(accessToken: String, accountID: Int) async throws -> [HarvestProjectSummary]
    func createTimeEntries(
        _ submissions: [StoredTimeEntryRecord.HarvestSubmission],
        accessToken: String
    ) async throws -> [HarvestCreatedTimeEntryDTO]
}

struct HarvestService: HarvestServicing {
    private let httpClient: HTTPClient
    private let decoder: JSONDecoder

    init(httpClient: HTTPClient, decoder: JSONDecoder = JSONDecoder()) {
        self.httpClient = httpClient
        self.decoder = decoder
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func fetchAccounts(accessToken: String) async throws -> [HarvestAccountSummary] {
        let request = HarvestRequestFactory.makeAccountsRequest(accessToken: accessToken)
        let (data, _) = try await performData(request)

        if let accounts = try? decoder.decode([HarvestAccountDTO].self, from: data) {
            return accounts.map { HarvestAccountSummary(id: $0.id, name: $0.name) }
        }

        let envelope = try decoder.decode(HarvestAccountsEnvelopeDTO.self, from: data)
        return envelope.accounts.map { HarvestAccountSummary(id: $0.id, name: $0.name) }
    }

    func fetchCurrentUser(accessToken: String, accountID: Int) async throws -> HarvestCurrentUserDTO {
        try await perform(
            HarvestRequestFactory.makeCurrentUserRequest(
                accessToken: accessToken,
                accountID: accountID
            )
        )
    }

    func fetchProjectAssignments(accessToken: String, accountID: Int) async throws -> [HarvestProjectSummary] {
        let request = HarvestRequestFactory.makeProjectAssignmentsRequest(
            accessToken: accessToken,
            accountID: accountID
        )
        let (data, _) = try await performData(request)

        let assignments: [HarvestProjectAssignmentDTO]
        if let directAssignments = try? decoder.decode([HarvestProjectAssignmentDTO].self, from: data) {
            assignments = directAssignments
        } else {
            assignments = try decoder.decode(HarvestProjectAssignmentsEnvelopeDTO.self, from: data).projectAssignments
        }

        return assignments.compactMap { assignment in
            guard assignment.isActive != false else { return nil }

            let tasks = assignment.taskAssignments.compactMap { taskAssignment -> HarvestTaskSummary? in
                guard taskAssignment.isActive != false else { return nil }
                return HarvestTaskSummary(
                    id: taskAssignment.task.id,
                    name: taskAssignment.task.name
                )
            }

            guard !tasks.isEmpty else { return nil }

            return HarvestProjectSummary(
                id: assignment.project.id,
                name: assignment.project.name,
                taskAssignments: tasks
            )
        }
    }

    func createTimeEntries(
        _ submissions: [StoredTimeEntryRecord.HarvestSubmission],
        accessToken: String
    ) async throws -> [HarvestCreatedTimeEntryDTO] {
        var createdEntries: [HarvestCreatedTimeEntryDTO] = []

        for submission in submissions {
            do {
                let created = try await createTimeEntry(
                    submission,
                    accessToken: accessToken
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

    private func createTimeEntry(
        _ submission: StoredTimeEntryRecord.HarvestSubmission,
        accessToken: String
    ) async throws -> HarvestCreatedTimeEntryDTO {
        let timestampRequest = try HarvestRequestFactory.makeCreateTimeEntryRequest(
            accessToken: accessToken,
            accountID: submission.accountID,
            payload: submission.timestampRequest
        )

        do {
            return try await perform(timestampRequest, expectedStatusCodes: 200..<300)
        } catch let error as PlannerServiceError {
            switch error {
            case let .api(statusCode, _) where statusCode == 422:
                let durationRequest = try HarvestRequestFactory.makeCreateTimeEntryRequest(
                    accessToken: accessToken,
                    accountID: submission.accountID,
                    payload: submission.durationFallbackRequest
                )
                return try await perform(durationRequest, expectedStatusCodes: 200..<300)
            default:
                throw error
            }
        }
    }

    private func perform<T: Decodable>(
        _ request: URLRequest,
        expectedStatusCodes: Range<Int> = 200..<300
    ) async throws -> T {
        let (data, _) = try await performData(request, expectedStatusCodes: expectedStatusCodes)

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw PlannerServiceError.decoding("Could not decode the Harvest response.")
        }
    }

    private func performData(
        _ request: URLRequest,
        expectedStatusCodes: Range<Int> = 200..<300
    ) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await httpClient.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlannerServiceError.invalidResponse
        }

        guard expectedStatusCodes.contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown Harvest error"
            throw PlannerServiceError.api(statusCode: httpResponse.statusCode, message: message)
        }

        return (data, httpResponse)
    }
}
