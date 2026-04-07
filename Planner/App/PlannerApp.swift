import SwiftUI

@main
struct PlannerApp: App {
    @StateObject private var appModel = PlannerAppModel.live()

    var body: some Scene {
        WindowGroup {
            PlannerRootView()
                .environmentObject(appModel)
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(appModel)
        }
        #endif
    }
}
