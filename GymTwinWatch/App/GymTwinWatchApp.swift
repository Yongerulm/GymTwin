import SwiftUI

@main
struct GymTwinWatchApp: App {
    @State private var store = WatchDataStore()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(store)
                .task { store.activate() }
        }
    }
}
