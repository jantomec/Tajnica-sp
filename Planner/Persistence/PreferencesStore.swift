import Foundation

final class PreferencesStore {
    private enum Keys {
        static let selectedWorkspaceID = "selectedWorkspaceID"
        static let selectedWorkspaceName = "selectedWorkspaceName"
        static let selectedLLMProvider = "selectedLLMProvider"
        static let selectedLLMModel = "selectedLLMModel"
        static let selectedTimeTracker = "selectedTimeTracker"
        static let userContext = "userContext"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var selectedWorkspaceID: Int? {
        get {
            userDefaults.object(forKey: Keys.selectedWorkspaceID) as? Int
        }
        set {
            setOptional(newValue, forKey: Keys.selectedWorkspaceID)
        }
    }

    var selectedWorkspaceName: String? {
        get {
            userDefaults.string(forKey: Keys.selectedWorkspaceName)
        }
        set {
            setOptional(newValue, forKey: Keys.selectedWorkspaceName)
        }
    }

    var selectedLLMProvider: LLMProvider {
        get {
            guard let raw = userDefaults.string(forKey: Keys.selectedLLMProvider),
                  let provider = LLMProvider(rawValue: raw) else {
                return .gemini
            }
            return provider
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: Keys.selectedLLMProvider)
        }
    }

    var selectedLLMModel: String? {
        get { userDefaults.string(forKey: Keys.selectedLLMModel) }
        set { setOptional(newValue, forKey: Keys.selectedLLMModel) }
    }

    func llmModel(for provider: LLMProvider) -> String? {
        userDefaults.string(forKey: "\(Keys.selectedLLMModel).\(provider.rawValue)")
    }

    func setLLMModel(_ value: String?, for provider: LLMProvider) {
        setOptional(value, forKey: "\(Keys.selectedLLMModel).\(provider.rawValue)")
    }

    var selectedTimeTracker: TimeTrackerProvider {
        get {
            guard let raw = userDefaults.string(forKey: Keys.selectedTimeTracker),
                  let provider = TimeTrackerProvider(rawValue: raw) else {
                return .toggl
            }
            return provider
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: Keys.selectedTimeTracker)
        }
    }

    var userContext: String {
        get { userDefaults.string(forKey: Keys.userContext) ?? "" }
        set { userDefaults.set(newValue, forKey: Keys.userContext) }
    }

    func storeResolvedWorkspace(_ workspace: WorkspaceSummary?) {
        selectedWorkspaceID = workspace?.id
        selectedWorkspaceName = workspace?.name
    }

    private func setOptional(_ value: Any?, forKey key: String) {
        if let value {
            userDefaults.set(value, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }
}
