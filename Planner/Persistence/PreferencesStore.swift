import Foundation

final class PreferencesStore {
    private enum Keys {
        static let selectedWorkspaceID = "selectedWorkspaceID"
        static let selectedWorkspaceName = "selectedWorkspaceName"
        static let selectedClockifyWorkspaceID = "selectedClockifyWorkspaceID"
        static let selectedClockifyWorkspaceName = "selectedClockifyWorkspaceName"
        static let selectedHarvestAccountID = "selectedHarvestAccountID"
        static let selectedHarvestAccountName = "selectedHarvestAccountName"
        static let selectedHarvestProjectID = "selectedHarvestProjectID"
        static let selectedHarvestProjectName = "selectedHarvestProjectName"
        static let selectedHarvestTaskID = "selectedHarvestTaskID"
        static let selectedHarvestTaskName = "selectedHarvestTaskName"
        static let selectedLLMProvider = "selectedLLMProvider"
        static let selectedLLMModel = "selectedLLMModel"
        static let appleIntelligenceEnabled = "appleIntelligenceEnabled"
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

    var selectedClockifyWorkspaceID: String? {
        get { userDefaults.string(forKey: Keys.selectedClockifyWorkspaceID) }
        set { setOptional(newValue, forKey: Keys.selectedClockifyWorkspaceID) }
    }

    var selectedClockifyWorkspaceName: String? {
        get { userDefaults.string(forKey: Keys.selectedClockifyWorkspaceName) }
        set { setOptional(newValue, forKey: Keys.selectedClockifyWorkspaceName) }
    }

    var selectedHarvestAccountID: Int? {
        get { userDefaults.object(forKey: Keys.selectedHarvestAccountID) as? Int }
        set { setOptional(newValue, forKey: Keys.selectedHarvestAccountID) }
    }

    var selectedHarvestAccountName: String? {
        get { userDefaults.string(forKey: Keys.selectedHarvestAccountName) }
        set { setOptional(newValue, forKey: Keys.selectedHarvestAccountName) }
    }

    var selectedHarvestProjectID: Int? {
        get { userDefaults.object(forKey: Keys.selectedHarvestProjectID) as? Int }
        set { setOptional(newValue, forKey: Keys.selectedHarvestProjectID) }
    }

    var selectedHarvestProjectName: String? {
        get { userDefaults.string(forKey: Keys.selectedHarvestProjectName) }
        set { setOptional(newValue, forKey: Keys.selectedHarvestProjectName) }
    }

    var selectedHarvestTaskID: Int? {
        get { userDefaults.object(forKey: Keys.selectedHarvestTaskID) as? Int }
        set { setOptional(newValue, forKey: Keys.selectedHarvestTaskID) }
    }

    var selectedHarvestTaskName: String? {
        get { userDefaults.string(forKey: Keys.selectedHarvestTaskName) }
        set { setOptional(newValue, forKey: Keys.selectedHarvestTaskName) }
    }

    var selectedLLMProvider: LLMProvider {
        get {
            guard let raw = userDefaults.string(forKey: Keys.selectedLLMProvider),
                  let provider = LLMProvider(rawValue: raw),
                  provider.isSelectableExternalProvider else {
                return .gemini
            }
            return provider
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: Keys.selectedLLMProvider)
        }
    }

    var isAppleIntelligenceEnabled: Bool {
        get {
            if userDefaults.object(forKey: Keys.appleIntelligenceEnabled) == nil {
                return true
            }
            return userDefaults.bool(forKey: Keys.appleIntelligenceEnabled)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.appleIntelligenceEnabled)
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

    var userContext: String {
        get { userDefaults.string(forKey: Keys.userContext) ?? "" }
        set { userDefaults.set(newValue, forKey: Keys.userContext) }
    }

    func storeResolvedWorkspace(_ workspace: WorkspaceSummary?) {
        selectedWorkspaceID = workspace?.id
        selectedWorkspaceName = workspace?.name
    }

    func storeResolvedClockifyWorkspace(_ workspace: ClockifyWorkspaceSummary?) {
        selectedClockifyWorkspaceID = workspace?.id
        selectedClockifyWorkspaceName = workspace?.name
    }

    func storeResolvedHarvestAccount(_ account: HarvestAccountSummary?) {
        selectedHarvestAccountID = account?.id
        selectedHarvestAccountName = account?.name
    }

    func storeResolvedHarvestProject(_ project: HarvestProjectSummary?) {
        selectedHarvestProjectID = project?.id
        selectedHarvestProjectName = project?.name
    }

    func storeResolvedHarvestTask(_ task: HarvestTaskSummary?) {
        selectedHarvestTaskID = task?.id
        selectedHarvestTaskName = task?.name
    }

    private func setOptional(_ value: Any?, forKey key: String) {
        if let value {
            userDefaults.set(value, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }
}
