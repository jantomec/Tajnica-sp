import Foundation
import Security
import Testing

@testable import Tajnica_sp

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

    @Test
    func persistsClockifyWorkspaceSelection() throws {
        let suiteName = "PlannerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let firstStore = PreferencesStore(userDefaults: defaults)
        firstStore.storeResolvedClockifyWorkspace(
            ClockifyWorkspaceSummary(id: "workspace-1", name: "Clockify")
        )

        let secondStore = PreferencesStore(userDefaults: defaults)

        #expect(secondStore.selectedClockifyWorkspaceID == "workspace-1")
        #expect(secondStore.selectedClockifyWorkspaceName == "Clockify")

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test
    func appleIntelligenceDefaultsToEnabled() throws {
        let suiteName = "PlannerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let store = PreferencesStore(userDefaults: defaults)

        #expect(store.isAppleIntelligenceEnabled)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test
    func persistsAppleIntelligenceEnabledState() throws {
        let suiteName = "PlannerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let firstStore = PreferencesStore(userDefaults: defaults)
        firstStore.isAppleIntelligenceEnabled = false

        let secondStore = PreferencesStore(userDefaults: defaults)

        #expect(secondStore.isAppleIntelligenceEnabled == false)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test
    func legacyAppleSelectionFallsBackToGeminiExternalProvider() throws {
        let suiteName = "PlannerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(LLMProvider.appleFoundation.rawValue, forKey: "selectedLLMProvider")

        let store = PreferencesStore(userDefaults: defaults)

        #expect(store.selectedLLMProvider == .gemini)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test
    func persistsDisabledCloudProviderSelection() throws {
        let suiteName = "PlannerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let firstStore = PreferencesStore(userDefaults: defaults)
        firstStore.selectedLLMProvider = .disabled

        let secondStore = PreferencesStore(userDefaults: defaults)

        #expect(secondStore.selectedLLMProvider == .disabled)

        defaults.removePersistentDomain(forName: suiteName)
    }
}

struct KeychainStoreTests {
    @Test
    func synchronizableSecretsRoundTrip() {
        let context = KeychainTestContext()
        defer { context.cleanup() }

        let store = KeychainStore(service: context.service)
        store.set("secret", for: .openAIAPIKey)

        #expect(store.string(for: .openAIAPIKey) == "secret")

        store.removeValue(for: .openAIAPIKey)

        #expect(store.string(for: .openAIAPIKey) == nil)
    }

    @Test
    func readsExistingLocalSecret() throws {
        let context = KeychainTestContext()
        defer { context.cleanup() }

        let addStatus = SecItemAdd(context.localQuery(for: .geminiAPIKey, value: "legacy-secret") as CFDictionary, nil)
        #expect(addStatus == errSecSuccess)

        let store = KeychainStore(service: context.service)

        #expect(store.string(for: .geminiAPIKey) == "legacy-secret")
    }
}

private struct KeychainTestContext {
    let service = "PlannerTests.Keychain.\(UUID().uuidString)"

    func cleanup() {
        for key in [
            KeychainKey.geminiAPIKey,
            .claudeAPIKey,
            .openAIAPIKey,
            .togglAPIToken,
            .clockifyAPIToken,
            .harvestAccessToken
        ] {
            SecItemDelete(localQuery(for: key) as CFDictionary)
            SecItemDelete(synchronizableQuery(for: key) as CFDictionary)
        }
    }

    func localQuery(for key: KeychainKey, value: String? = nil) -> [String: Any] {
        query(for: key, synchronizable: kCFBooleanFalse, value: value)
    }

    func synchronizableQuery(for key: KeychainKey, value: String? = nil) -> [String: Any] {
        query(for: key, synchronizable: kCFBooleanTrue, value: value)
    }

    private func query(
        for key: KeychainKey,
        synchronizable: CFBoolean,
        value: String? = nil
    ) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrSynchronizable as String: synchronizable
        ]

        if let value {
            query[kSecValueData as String] = Data(value.utf8)
        }

        return query
    }
}
