import Foundation
import Testing

@testable import Tajnica_sp

struct WorkspaceSelectionResolverTests {
    private let workspaces = [
        WorkspaceSummary(id: 1, name: "One"),
        WorkspaceSummary(id: 2, name: "Two")
    ]

    @Test
    func resolvesFirstWorkspaceWhenNoneSaved() {
        let resolved = WorkspaceSelectionResolver.resolve(savedWorkspaceID: nil, fetchedWorkspaces: workspaces)
        #expect(resolved?.id == 1)
    }

    @Test
    func keepsSavedWorkspaceWhenItStillExists() {
        let resolved = WorkspaceSelectionResolver.resolve(savedWorkspaceID: 2, fetchedWorkspaces: workspaces)
        #expect(resolved?.id == 2)
    }

    @Test
    func fallsBackToFirstWorkspaceWhenSavedWorkspaceIsMissing() {
        let resolved = WorkspaceSelectionResolver.resolve(savedWorkspaceID: 999, fetchedWorkspaces: workspaces)
        #expect(resolved?.id == 1)
    }
}
