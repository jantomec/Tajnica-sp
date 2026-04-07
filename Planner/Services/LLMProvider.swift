import Foundation

enum LLMProvider: String, CaseIterable, Identifiable, Codable {
    case gemini
    case claude
    case openAI

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gemini: "Google Gemini"
        case .claude: "Anthropic Claude"
        case .openAI: "OpenAI ChatGPT"
        }
    }

    var defaultModel: String {
        switch self {
        case .gemini: AppConfiguration.defaultGeminiModel
        case .claude: AppConfiguration.defaultClaudeModel
        case .openAI: AppConfiguration.defaultOpenAIModel
        }
    }

    var keychainKey: KeychainKey {
        switch self {
        case .gemini: .geminiAPIKey
        case .claude: .claudeAPIKey
        case .openAI: .openAIAPIKey
        }
    }

    var apiKeyLabel: String {
        switch self {
        case .gemini: "Gemini API Key"
        case .claude: "Claude API Key"
        case .openAI: "OpenAI API Key"
        }
    }
}
