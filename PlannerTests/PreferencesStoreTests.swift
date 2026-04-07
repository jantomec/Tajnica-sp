import Foundation
import Testing

@testable import Planner

struct PreferencesStoreTests {
    @Test
    func persistsSelectedWorkspaceIdentifier() throws {
        let suiteName = "PlannerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let firstStore = PreferencesStore(userDefaults: defaults)
        firstStore.selectedWorkspaceID = 42
        firstStore.selectedWorkspaceName = "Workspace"

        let secondStore = PreferencesStore(userDefaults: defaults)

        #expect(secondStore.selectedWorkspaceID == 42)
        #expect(secondStore.selectedWorkspaceName == "Workspace")

        defaults.removePersistentDomain(forName: suiteName)
    }
}
