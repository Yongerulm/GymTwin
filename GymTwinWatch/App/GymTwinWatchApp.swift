import SwiftUI

@main
struct GymTwinWatchApp: App {
    @State private var store = WatchDataStore.shared

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(store)
                .task { store.activate() }
        }
    }
}
