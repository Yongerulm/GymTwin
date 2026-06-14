import SwiftUI
import SwiftData

@main
struct GymTwinApp: App {
    let container: ModelContainer
    @State private var syncCoordinator: SyncCoordinator

    init() {
        let container = PersistenceController.makeContainer()
        self.container = container
        // Seed sample data on first launch so the app is never empty.
        SampleData.seedIfNeeded(container.mainContext)
        _syncCoordinator = State(initialValue: SyncCoordinator(context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .task {
                    // Activate WatchConnectivity and push the machine catalog.
                    syncCoordinator.start()
                }
        }
        .modelContainer(container)
    }
}
