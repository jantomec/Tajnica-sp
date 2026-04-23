import FoundationModels
import Foundation
import Testing

@testable import Tajnica_sp

struct AppleFoundationModelsServiceTests {
    @Test
    func allowsAvailabilityChecksOnSimulatorWhenSystemModelReportsAvailable() throws {
        let service = AppleFoundationModelsService(
            availabilityProvider: { .available },
            isSimulator: true
        )

        #expect(throws: Never.self) {
            try service.checkAppleIntelligenceAvailability()
        }
    }

    @Test
    func explainsWhenDeviceIsNotEligible() async {
        let service = AppleFoundationModelsService(
            availabilityProvider: { .unavailable(SystemLanguageModel.Availability.UnavailableReason.deviceNotEligible) }
        )

        await #expect(throws: PlannerServiceError.emptyResponse("Apple Foundation Models is unavailable because this device is not eligible for Apple Intelligence. Use a supported Apple device or switch to a cloud provider.")) {
            _ = try await service.testConnection(apiKey: "", model: "")
        }
    }

    @Test
    func guidesUsersToEnableAppleIntelligence() async {
        let service = AppleFoundationModelsService(
            availabilityProvider: { .unavailable(SystemLanguageModel.Availability.UnavailableReason.appleIntelligenceNotEnabled) }
        )

        await #expect(throws: PlannerServiceError.emptyResponse("Apple Intelligence is turned off on this device. Enable it in Apple Intelligence & Siri settings, then try again.")) {
            _ = try await service.testConnection(apiKey: "", model: "")
        }
    }

    @Test
    func asksUsersToTryAgainLaterWhenModelIsNotReady() async {
        let service = AppleFoundationModelsService(
            availabilityProvider: { .unavailable(SystemLanguageModel.Availability.UnavailableReason.modelNotReady) }
        )

        await #expect(throws: PlannerServiceError.emptyResponse("Apple Foundation Models is not ready yet. The on-device model is still preparing. Please try again later.")) {
            _ = try await service.testConnection(apiKey: "", model: "")
        }
    }
}
