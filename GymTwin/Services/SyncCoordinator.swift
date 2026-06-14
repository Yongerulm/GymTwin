import Foundation
import SwiftData

/// Bridges WatchConnectivity to the local SwiftData store on the iPhone.
///
/// - Pushes the current machine catalog to the watch.
/// - Ingests completed workouts coming back from the watch, de-duplicating by
///   `Workout.id` so repeated deliveries are idempotent.
@MainActor
final class SyncCoordinator {
    private let context: ModelContext
    private let connectivity: WatchConnectivityService
    private let gymName: String

    init(
        context: ModelContext,
        connectivity: WatchConnectivityService = .shared,
        gymName: String = "Gym Twin"
    ) {
        self.context = context
        self.connectivity = connectivity
        self.gymName = gymName
    }

    /// Wire up incoming-workout handling and activate the session.
    func start() {
        connectivity.onReceiveWorkout = { [weak self] dto in
            self?.ingest(workout: dto)
        }
        connectivity.activate()
        pushCatalog()
    }

    /// Build a catalog snapshot from the store and send it to the watch.
    func pushCatalog() {
        let machines = (try? context.fetch(FetchDescriptor<Machine>())) ?? []
        let catalog = GymCatalogDTO(
            gymName: gymName,
            machines: machines
                .sorted { $0.sortIndex < $1.sortIndex }
                .map(MachineDTO.init(machine:)),
            generatedAt: Date()
        )
        connectivity.sendCatalog(catalog)
    }

    /// Persist a workout received from the watch, ignoring duplicates.
    private func ingest(workout dto: WorkoutDTO) {
        let targetID = dto.id
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.id == targetID }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        context.insert(dto.makeWorkout())
        try? context.save()
    }
}
