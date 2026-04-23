import Foundation

enum WorkspaceSelectionResolver {
    static func resolve(savedWorkspaceID: Int?, fetchedWorkspaces: [WorkspaceSummary]) -> WorkspaceSummary? {
        guard !fetchedWorkspaces.isEmpty else { return nil }

        if let savedWorkspaceID,
           let match = fetchedWorkspaces.first(where: { $0.id == savedWorkspaceID }) {
            return match
        }

        return fetchedWorkspaces.first
    }

    static func resolve(savedWorkspaceID: String?, fetchedWorkspaces: [ClockifyWorkspaceSummary]) -> ClockifyWorkspaceSummary? {
        guard !fetchedWorkspaces.isEmpty else { return nil }

        if let savedWorkspaceID,
           let match = fetchedWorkspaces.first(where: { $0.id == savedWorkspaceID }) {
            return match
        }

        return fetchedWorkspaces.first
    }
}
