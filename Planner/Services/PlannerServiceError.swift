import Foundation

enum PlannerServiceError: LocalizedError, Equatable {
    case missingCredential(String)
    case invalidResponse
    case emptyResponse(String)
    case api(statusCode: Int, message: String)
    case decoding(String)
    case noResolvedWorkspace
    case partialSubmission(createdCount: Int, totalCount: Int, message: String)

    var errorDescription: String? {
        switch self {
        case let .missingCredential(name):
            return "\(name) is missing."
        case .invalidResponse:
            return "The server returned an invalid response."
        case let .emptyResponse(message):
            return message
        case let .api(statusCode, message):
            return "Request failed (\(statusCode)): \(message)"
        case let .decoding(message):
            return message
        case .noResolvedWorkspace:
            return "No workspace could be resolved from live Toggl data."
        case let .partialSubmission(createdCount, totalCount, message):
            return "Submitted \(createdCount) of \(totalCount) entries before failing: \(message)"
        }
    }
}
