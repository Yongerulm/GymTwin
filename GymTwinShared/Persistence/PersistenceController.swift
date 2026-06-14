import Foundation
import SwiftData

/// Builds the app's SwiftData `ModelContainer`. Centralising the schema here
/// keeps both app entry points small and gives tests an in-memory container.
///
/// The on-disk store lives in a shared App Group so the iPhone and the Apple
/// Watch read the same data. WatchConnectivity remains the authoritative
/// real-time sync channel; the shared container is the durable backing store.
enum PersistenceController {
    /// Every persisted model type in the app, used by both platforms.
    static let schema = Schema([
        Gym.self,
        GymArea.self,
        Machine.self,
        MachineSetting.self,
        Workout.self,
        WorkoutExercise.self,
        WorkoutSet.self,
        WorkoutPlan.self,
        PlanExercise.self,
    ])

    /// The shared, durable container used by the running apps. Falls back
    /// gracefully so a provisioning or storage problem never hard-crashes the
    /// app on launch.
    static func makeContainer() -> ModelContainer {
        // Preferred: shared App Group store, readable by phone + watch.
        // Only attempt it when the App Group entitlement is actually
        // provisioned — otherwise SwiftData raises an uncatchable fatal error.
        let groupAvailable = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) != nil
        if groupAvailable {
            let groupConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                groupContainer: .identifier(AppGroup.identifier)
            )
            if let container = try? ModelContainer(for: schema, configurations: [groupConfig]) {
                return container
            }
        }

        // Fallback: per-app default store (e.g. App Group not provisioned).
        let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        if let container = try? ModelContainer(for: schema, configurations: [localConfig]) {
            return container
        }

        // Last resort: a fresh in-memory store keeps the app usable.
        return makeInMemoryContainer()
    }

    /// An ephemeral in-memory container for previews and unit tests.
    static func makeInMemoryContainer() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        // A failing in-memory container indicates a programmer error in the
        // schema itself, which should surface loudly during development.
        // swiftlint:disable:next force_try
        return try! ModelContainer(for: schema, configurations: [configuration])
    }
}
