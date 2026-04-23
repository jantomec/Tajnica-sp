import Foundation

enum LLMProvider: String, CaseIterable, Identifiable, Codable {
    case appleFoundation
    case disabled
    case gemini
    case claude
    case openAI

    var id: String { rawValue }

    static var selectableExternalProviders: [LLMProvider] {
        allCases.filter(\.isSelectableExternalProvider)
    }

    var isExternalProvider: Bool {
        switch self {
        case .gemini, .claude, .openAI:
            true
        case .appleFoundation, .disabled:
            false
        }
    }

    var isSelectableExternalProvider: Bool {
        self != .appleFoundation
    }

    var shortName: String {
        switch self {
        case .appleFoundation: "Apple"
        case .disabled: "Disable"
        case .gemini: "Gemini"
        case .claude: "Claude"
        case .openAI: "OpenAI"
        }
    }

    var displayName: String {
        switch self {
        case .appleFoundation: "Apple Foundation Models"
        case .disabled: "Disabled"
        case .gemini: "Google Gemini"
        case .claude: "Anthropic Claude"
        case .openAI: "OpenAI ChatGPT"
        }
    }

    var defaultModel: String {
        switch self {
        case .appleFoundation: AppConfiguration.defaultAppleFoundationModel
        case .disabled: ""
        case .gemini: AppConfiguration.defaultGeminiModel
        case .claude: AppConfiguration.defaultClaudeModel
        case .openAI: AppConfiguration.defaultOpenAIModel
        }
    }

    var keychainKey: KeychainKey? {
        switch self {
        case .appleFoundation: nil
        case .disabled: nil
        case .gemini: .geminiAPIKey
        case .claude: .claudeAPIKey
        case .openAI: .openAIAPIKey
        }
    }

    var requiresAPIKey: Bool {
        keychainKey != nil
    }

    var supportsCustomModelSelection: Bool {
        switch self {
        case .appleFoundation, .disabled: false
        case .gemini, .claude, .openAI: true
        }
    }

    var configurationSectionTitle: String {
        switch self {
        case .appleFoundation: "Apple On-Device Model"
        case .disabled: "External AI Disabled"
        case .gemini, .claude, .openAI: "\(displayName) Configuration"
        }
    }

    var apiKeyLabel: String {
        switch self {
        case .appleFoundation: "No API Key Required"
        case .disabled: "No API Key Required"
        case .gemini: "Gemini API Key"
        case .claude: "Claude API Key"
        case .openAI: "OpenAI API Key"
        }
    }

    var connectionButtonTitle: String {
        switch self {
        case .appleFoundation: "Check Availability"
        case .disabled: "Disabled"
        case .gemini, .claude, .openAI: "Test Connection"
        }
    }

    func connectionSuccessMessage(status: String) -> String {
        switch self {
        case .appleFoundation: "\(displayName) ready (\(status))."
        case .disabled: "External AI is disabled."
        case .gemini, .claude, .openAI: "\(displayName) connected (\(status))."
        }
    }

    var tradeoffSummary: String {
        switch self {
        case .appleFoundation:
            "Runs on-device with Apple Intelligence, so it is private, fast, and does not need an API key. It depends on supported Apple hardware and can be less capable than cloud models for harder reasoning or multilingual notes."
        case .disabled:
            "No cloud AI provider is selected. \(AppConfiguration.displayName) will use Apple Intelligence only when it is enabled and available on this device."
        case .gemini, .claude, .openAI:
            "Runs in the cloud, so it needs an API key and sends note content to the selected provider. Cloud models are usually stronger for nuanced reasoning, model choice, and broader multilingual support."
        }
    }

    var configurationHint: String? {
        switch self {
        case .appleFoundation:
            "\(AppConfiguration.displayName) uses Apple's built-in on-device model. There is no remote model ID or API key to configure. If availability fails, the device may not support Apple Intelligence, Apple Intelligence may be turned off, or the model may still be preparing."
        case .disabled:
            "Choose Disable if you do not want \(AppConfiguration.displayName) to use Gemini, Claude, or OpenAI as the primary AI provider."
        case .gemini, .claude, .openAI:
            nil
        }
    }
}
