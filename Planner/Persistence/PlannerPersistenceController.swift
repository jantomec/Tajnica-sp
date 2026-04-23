import CoreData
import Foundation
import SwiftData

@MainActor
final class PlannerPersistenceController {
    enum SyncMode: Equatable {
        case cloudKit
        case localOnlyFallback
    }

    let modelContainer: ModelContainer
    let repository: SwiftDataPlannerSyncRepository
    let syncMode: SyncMode

    init(
        modelContainer: ModelContainer,
        repository: SwiftDataPlannerSyncRepository,
        syncMode: SyncMode
    ) {
        self.modelContainer = modelContainer
        self.repository = repository
        self.syncMode = syncMode
    }

    static func live() throws -> PlannerPersistenceController {
        let schema = syncSchema()

        do {
            let configuration = cloudKitConfiguration(schema: schema)

            return try makeController(
                schema: schema,
                configuration: configuration,
                syncMode: .cloudKit
            )
        } catch {
            guard shouldFallBackToLocalStore(for: error) else {
                throw error
            }

            return try makeController(
                schema: schema,
                configuration: localPersistentConfiguration(schema: schema),
                syncMode: .localOnlyFallback
            )
        }
    }

    static func inMemory() throws -> PlannerPersistenceController {
        let schema = syncSchema()
        let configuration = ModelConfiguration(
            "PlannerSyncInMemory",
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try makeController(
            schema: schema,
            configuration: configuration,
            syncMode: .localOnlyFallback
        )
    }

    nonisolated static func shouldFallBackToLocalStore(for error: Error) -> Bool {
        containsRecoverableCloudKitStartupFailure(error as NSError)
    }

    private static func makeController(
        schema: Schema,
        configuration: ModelConfiguration,
        syncMode: SyncMode
    ) throws -> PlannerPersistenceController {
        let modelContainer = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        let repository = SwiftDataPlannerSyncRepository(
            modelContainer: modelContainer
        )

        return PlannerPersistenceController(
            modelContainer: modelContainer,
            repository: repository,
            syncMode: syncMode
        )
    }

    private static func syncSchema() -> Schema {
        Schema([
            SyncedDiaryPrompt.self,
            SyncedCurrentDraft.self,
            SyncedStoredTimeEntry.self
        ])
    }

    private static func cloudKitConfiguration(schema: Schema) -> ModelConfiguration {
        ModelConfiguration(
            "PlannerSync",
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .automatic,
            cloudKitDatabase: .private(AppConfiguration.cloudKitContainerIdentifier)
        )
    }

    private static func localPersistentConfiguration(schema: Schema) -> ModelConfiguration {
        ModelConfiguration(
            "PlannerSync",
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .automatic
        )
    }

    nonisolated private static func containsRecoverableCloudKitStartupFailure(_ error: NSError) -> Bool {
        if let reason = error.userInfo[NSLocalizedFailureReasonErrorKey] as? String,
           isRecoverableCloudKitFailureReason(reason) {
            return true
        }

        for nestedError in nestedErrors(from: error) {
            if containsRecoverableCloudKitStartupFailure(nestedError) {
                return true
            }
        }

        return false
    }

    nonisolated private static func nestedErrors(from error: NSError) -> [NSError] {
        var nestedErrors: [NSError] = []

        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            nestedErrors.append(underlying)
        }

        if let detailedErrors = error.userInfo[NSDetailedErrorsKey] as? [NSError] {
            nestedErrors.append(contentsOf: detailedErrors)
        }

        if let encounteredErrors = error.userInfo["encounteredErrors"] as? [NSError] {
            nestedErrors.append(contentsOf: encounteredErrors)
        }

        return nestedErrors
    }

    nonisolated private static func isRecoverableCloudKitFailureReason(_ reason: String) -> Bool {
        reason.contains("Unable to initialize without an iCloud account")
            || reason.contains("CKAccountStatusNoAccount")
    }
}
