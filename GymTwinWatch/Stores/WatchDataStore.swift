import Foundation
import WatchKit

/// Central in-memory + persisted store for the watch app.
///
/// - Caches the synced `GymCatalogDTO` to UserDefaults (offline-safe).
/// - Manages the active workout (exercises + sets) entirely in memory.
/// - Owns a `WatchWorkoutSession` for live HealthKit metrics.
/// - Sends the finished `WorkoutDTO` to the iPhone via `WatchConnectivityService`.
@Observable
@MainActor
final class WatchDataStore {

    /// Shared instance so App Intents bound to the Apple Watch Action Button
    /// can drive the same live workout the UI shows.
    @MainActor static let shared = WatchDataStore()

    // MARK: - Catalog

    private(set) var gymName: String = ""
    private(set) var catalog: [MachineDTO] = []

    // MARK: - Active workout

    private(set) var isWorkoutActive = false
    private(set) var exercises: [WorkoutExerciseDTO] = []
    private(set) var workoutStartDate: Date?
    /// Elapsed seconds since the workout started (driven by a 1 s Task loop).
    private(set) var elapsedSeconds: Int = 0

    /// Index of the exercise the user is currently logging — the Action Button
    /// logs the next set against this one.
    var currentExerciseIndex: Int = 0

    // MARK: - Rest timer (shared with the Action Button)

    /// Preferred rest length in seconds (flexible, persisted, min 15 s).
    var restGoalSeconds: Int {
        get { max(15, defaults.object(forKey: restGoalKey) as? Int ?? 90) }
        set { defaults.set(max(15, min(newValue, 600)), forKey: restGoalKey) }
    }
    private(set) var isResting = false
    private(set) var restRemaining = 0
    private var restTask: Task<Void, Never>?
    private let restGoalKey = "gymtwin.rest.goal"

    // MARK: - HealthKit session

    let hkSession = WatchWorkoutSession()

    // MARK: - Persistence

    private let defaults = UserDefaults.standard
    private let catalogKey = "gymtwin.catalog"

    // MARK: - Activation

    /// Call exactly once at app launch. Wires connectivity callbacks then
    /// activates the WCSession.
    func activate() {
        loadPersistedCatalog()

        WatchConnectivityService.shared.onReceiveCatalog = { [weak self] dto in
            guard let self else { return }
            self.gymName = dto.gymName
            self.catalog = dto.machines
            self.persistCatalog(dto)
        }

        WatchConnectivityService.shared.activate()
    }

    // MARK: - Catalog persistence

    private func loadPersistedCatalog() {
        guard
            let data = defaults.data(forKey: catalogKey),
            let dto = try? JSONDecoder().decode(GymCatalogDTO.self, from: data)
        else { return }
        gymName = dto.gymName
        catalog = dto.machines
    }

    private func persistCatalog(_ dto: GymCatalogDTO) {
        guard let data = try? JSONEncoder().encode(dto) else { return }
        defaults.set(data, forKey: catalogKey)
    }

    // MARK: - Workout management

    /// Starts a new workout session. No-ops if one is already active.
    func start() {
        guard !isWorkoutActive else { return }
        exercises = []
        workoutStartDate = .now
        elapsedSeconds = 0
        isWorkoutActive = true
        startElapsedTimer()
        Task { await hkSession.start() }
    }

    /// Adds a machine to the active workout (or starts one if needed).
    /// Returns the index of the added/existing exercise entry.
    @discardableResult
    func addExercise(_ machine: MachineDTO) -> Int {
        if !isWorkoutActive { start() }
        if let idx = exercises.firstIndex(where: { $0.machineID == machine.id }) {
            return idx
        }
        let dto = WorkoutExerciseDTO(
            id: UUID(),
            machineID: machine.id,
            machineName: machine.name,
            sets: []
        )
        exercises.append(dto)
        return exercises.count - 1
    }

    /// Appends a logged set to the exercise at `index`.
    func addSet(weight: Double, reps: Int, toExerciseAt index: Int) {
        guard exercises.indices.contains(index) else { return }
        let setDTO = WorkoutSetDTO(
            id: UUID(),
            weight: weight,
            repetitions: reps,
            timestamp: .now
        )
        exercises[index].sets.append(setDTO)
    }

    /// Removes the most-recent set from the exercise at `index`.
    func removeLastSet(fromExerciseAt index: Int) {
        guard exercises.indices.contains(index),
              !exercises[index].sets.isEmpty
        else { return }
        exercises[index].sets.removeLast()
    }

    /// Finishes the workout, sends it to iPhone, then resets state.
    func finish() {
        guard isWorkoutActive, let start = workoutStartDate else { return }
        let end = Date.now
        let dto = WorkoutDTO(
            id: UUID(),
            date: start,
            duration: end.timeIntervalSince(start),
            notes: "",
            exercises: exercises
        )
        WatchConnectivityService.shared.sendWorkout(dto)
        Task { await hkSession.end() }
        resetWorkout()
    }

    // MARK: - Action Button + rest

    /// One-press flow for the Apple Watch Ultra Action Button: log the next set
    /// against the current exercise (mirroring the last set's weight/reps), give
    /// a success haptic, and start the rest countdown. Falls back to sensible
    /// defaults when no previous set exists.
    func logNextSet() {
        guard isWorkoutActive, exercises.indices.contains(currentExerciseIndex) else { return }
        let last = exercises[currentExerciseIndex].sets.last
        addSet(
            weight: last?.weight ?? 20,
            reps: last?.repetitions ?? 10,
            toExerciseAt: currentExerciseIndex
        )
        WKInterfaceDevice.current().play(.success)
        startRest()
    }

    /// Start (or restart) the rest countdown from the preferred goal.
    func startRest(seconds: Int? = nil) {
        let goal = seconds ?? restGoalSeconds
        restTask?.cancel()
        restRemaining = max(0, goal)
        isResting = true
        restTask = Task { [weak self] in
            while let self, self.isResting, self.restRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.restRemaining -= 1
            }
            if let self, self.restRemaining <= 0 {
                self.isResting = false
                WKInterfaceDevice.current().play(.stop)
            }
        }
    }

    /// Skip the current rest and jump straight to the next set.
    func skipRest() {
        restTask?.cancel()
        restTask = nil
        isResting = false
        restRemaining = 0
    }

    // MARK: - Private helpers

    private func resetWorkout() {
        skipRest()
        isWorkoutActive = false
        exercises = []
        workoutStartDate = nil
        elapsedSeconds = 0
    }

    private func startElapsedTimer() {
        Task { [weak self] in
            while let self, self.isWorkoutActive {
                try? await Task.sleep(for: .seconds(1))
                self.elapsedSeconds += 1
            }
        }
    }
}
