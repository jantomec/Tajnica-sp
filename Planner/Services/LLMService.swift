import Foundation

protocol AppleIntelligenceAvailabilityChecking {
    func checkAppleIntelligenceAvailability() throws
}

/// Unified protocol for all LLM backends used by Planner.
protocol LLMServicing {
    func extractTimeEntries(
        apiKey: String,
        model: String,
        note: DailyNoteInput,
        timeZone: TimeZone,
        extractionContext: LLMExtractionContext
    ) async throws -> GeminiExtractionResponse

    func testConnection(apiKey: String, model: String) async throws -> String

    func polishUserContext(apiKey: String, model: String, rawText: String) async throws -> String
}

/// Routes LLM calls to the active provider's service implementation.
struct LLMServiceRouter {
    private let appleFoundationService: LLMServicing
    private let appleIntelligenceAvailabilityChecker: AppleIntelligenceAvailabilityChecking
    private let geminiService: LLMServicing
    private let claudeService: LLMServicing
    private let openAIService: LLMServicing

    init(
        appleFoundationService: any LLMServicing & AppleIntelligenceAvailabilityChecking,
        geminiService: LLMServicing,
        claudeService: LLMServicing,
        openAIService: LLMServicing
    ) {
        self.appleFoundationService = appleFoundationService
        self.appleIntelligenceAvailabilityChecker = appleFoundationService
        self.geminiService = geminiService
        self.claudeService = claudeService
        self.openAIService = openAIService
    }

    init(
        appleFoundationService: LLMServicing,
        geminiService: LLMServicing,
        claudeService: LLMServicing,
        openAIService: LLMServicing
    ) {
        guard let availabilityChecker = appleFoundationService as? AppleIntelligenceAvailabilityChecking else {
            preconditionFailure("appleFoundationService must support Apple Intelligence availability checks.")
        }

        self.appleFoundationService = appleFoundationService
        self.appleIntelligenceAvailabilityChecker = availabilityChecker
        self.geminiService = geminiService
        self.claudeService = claudeService
        self.openAIService = openAIService
    }

    func service(for provider: LLMProvider) -> LLMServicing {
        switch provider {
        case .appleFoundation: appleFoundationService
        case .disabled:
            preconditionFailure("Disabled provider does not map to an LLM service.")
        case .gemini: geminiService
        case .claude: claudeService
        case .openAI: openAIService
        }
    }

    func checkAppleIntelligenceAvailability() throws {
        try appleIntelligenceAvailabilityChecker.checkAppleIntelligenceAvailability()
    }
}
