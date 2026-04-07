import SwiftUI

struct PlannerRootView: View {
    @EnvironmentObject private var appModel: PlannerAppModel

    var body: some View {
        TabView(selection: $appModel.selectedTab) {
            NavigationStack {
                CaptureView()
            }
            .tabItem {
                Label("Capture", systemImage: "square.and.pencil")
            }
            .tag(PlannerAppModel.Tab.capture)

            NavigationStack {
                ReviewView()
            }
            .tabItem {
                Label("Review", systemImage: "calendar")
            }
            .tag(PlannerAppModel.Tab.review)

            #if !os(macOS)
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(PlannerAppModel.Tab.settings)
            #endif
        }
        .task {
            await appModel.start()
        }
    }
}
