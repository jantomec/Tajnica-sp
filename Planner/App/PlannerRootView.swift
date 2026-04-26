import SwiftUI

struct PlannerRootView: View {
    @EnvironmentObject private var appModel: PlannerAppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $appModel.selectedTab.deferredWrite()) {
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

            NavigationStack {
                DiaryView()
            }
            .tabItem {
                Label("Diary", systemImage: "book.closed")
            }
            .tag(PlannerAppModel.Tab.diary)

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
        .onChange(of: scenePhase) { _, newValue in
            Task {
                await appModel.handleScenePhaseChange(newValue)
            }
        }
        .onOpenURL { url in
            appModel.handleIncomingURL(url)
        }
    }
}

extension Binding where Value: Equatable {
    /// Skips no-op writes and defers real writes to the next runloop turn.
    /// Use when a SwiftUI control writes back to a `@Published` property during a
    /// view-update phase (e.g. `TabView` selection, `confirmationDialog` `isPresented`),
    /// which otherwise trips "Publishing changes from within view updates."
    func deferredWrite() -> Binding<Value> {
        Binding(
            get: { wrappedValue },
            set: { newValue in
                guard wrappedValue != newValue else { return }
                DispatchQueue.main.async { self.wrappedValue = newValue }
            }
        )
    }
}
