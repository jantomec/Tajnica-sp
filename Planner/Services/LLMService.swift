import Foundation

/// Unified protocol for all LLM backends used by Planner.
protocol LLMServicing {
    func extractTimeEntries(
        apiKey: String,
        model: String,
        note: DailyNoteInput,
        timeZone: TimeZone,
        userContext: String?,
        availableProjects: [String]
    ) async throws -> GeminiExtractionResponse

    func testConnection(apiKey: String, model: String) async throws -> String

    func polishUserContext(apiKey: String, model: String, rawText: String) async throws -> String
}

/// Routes LLM calls to the active provider's service implementation.
struct LLMServiceRouter {
    private let geminiService: LLMServicing
    private let claudeService: LLMServicing
    private let openAIService: LLMServicing

    init(
        geminiService: LLMServicing,
        claudeService: LLMServicing,
        openAIService: LLMServicing
    ) {
        self.geminiService = geminiService
        self.claudeService = claudeService
        self.openAIService = openAIService
    }

    func service(for provider: LLMProvider) -> LLMServicing {
        switch provider {
        case .gemini: geminiService
        case .claude: claudeService
        case .openAI: openAIService
        }
    }
}
