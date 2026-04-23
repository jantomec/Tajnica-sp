import AppIntents
import SwiftUI
import SwiftData

@main
struct PlannerApp: App {
    private let persistenceController: PlannerPersistenceController
    @StateObject private var appModel: PlannerAppModel

    init() {
        do {
            PlannerShortcutsProvider.updateAppShortcutParameters()

            let persistenceController: PlannerPersistenceController
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                persistenceController = try PlannerPersistenceController.inMemory()
            } else {
                persistenceController = try PlannerPersistenceController.live()
            }
            self.persistenceController = persistenceController
            _appModel = StateObject(
                wrappedValue: PlannerAppModel.live(
                    syncRepository: persistenceController.repository,
                    storageSyncMode: persistenceController.syncMode
                )
            )
        } catch {
            fatalError("Failed to initialize persistence: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            PlannerRootView()
                .environmentObject(appModel)
                .modelContainer(persistenceController.modelContainer)
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(appModel)
                .modelContainer(persistenceController.modelContainer)
        }
        #endif
    }
}
