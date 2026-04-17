import Foundation

enum PlannerDeepLink: Equatable {
    nonisolated static let scheme = "planner"

    case capture
    case review(entryID: UUID?)

    nonisolated init?(url: URL) {
        guard url.scheme?.caseInsensitiveCompare(Self.scheme) == .orderedSame else {
            return nil
        }

        let destination = url.host?.lowercased() ?? ""
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        switch destination {
        case "capture":
            self = .capture
        case "review":
            let entryID = components?.queryItems?
                .first(where: { $0.name == "entry" })?
                .value
                .flatMap(UUID.init(uuidString:))
            self = .review(entryID: entryID)
        default:
            return nil
        }
    }

    nonisolated var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme

        switch self {
        case .capture:
            components.host = "capture"
        case let .review(entryID):
            components.host = "review"
            if let entryID {
                components.queryItems = [
                    URLQueryItem(name: "entry", value: entryID.uuidString)
                ]
            }
        }

        guard let url = components.url else {
            preconditionFailure("Failed to build Planner deep link URL.")
        }

        return url
    }
}
