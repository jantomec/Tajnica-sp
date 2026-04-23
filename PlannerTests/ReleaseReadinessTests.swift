import Testing

@testable import Tajnica_sp

struct ReleaseReadinessTests {
    @Test
    func disabledLLMCopyUsesReleaseName() {
        #expect(LLMProvider.disabled.tradeoffSummary.contains(AppConfiguration.displayName))
        #expect(!LLMProvider.disabled.tradeoffSummary.contains("Planner will use"))
        #expect(LLMProvider.disabled.configurationHint?.contains(AppConfiguration.displayName) == true)
        #expect(LLMProvider.disabled.configurationHint?.contains("do not want Planner") == false)
    }

    @Test
    func exportFilenamePrefixMatchesReleaseBrand() {
        #expect(AppConfiguration.exportFilenamePrefix == "tajnica-sp-time-tracker")
        #expect(!AppConfiguration.exportFilenamePrefix.contains("planner"))
    }
}
