import Foundation
import SwiftData

// MARK: - In-memory draft types

/// A single logged set inside a draft exercise, held entirely in memory
/// until the session is finished.
struct DraftSet: Identifiable {
    let id: UUID
    var weight: Double
    var reps: Int
    var type: WorkoutSetType

    init(id: UUID = UUID(), weight: Double, reps: Int, type: WorkoutSetType = .working) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.type = type
    }
}

/// One machine's draft within the current session.
struct DraftExercise: Identifiable {
    let id: UUID
    let machineID: UUID
    let machineName: String
    var sets: [DraftSet]

    init(id: UUID = UUID(), machineID: UUID, machineName: String, sets: [DraftSet] = []) {
        self.id = id
        self.machineID = machineID
        self.machineName = machineName
        self.sets = sets
    }
}

// MARK: - ViewModel

/// Owns the in-progress workout session entirely in memory.
/// Calls `WorkoutService.persist` on finish and hands the UUID off to
/// HealthKit asynchronously.
@Observable
@MainActor
final class WorkoutViewModel {

    // MARK: Session state

    private(set) var isActive: Bool = false
    private(set) var startDate: Date = Date()
    private(set) var exercises: [DraftExercise] = []

    /// Live elapsed time updated every second while a session is active.
    private(set) var elapsedSeconds: Int = 0

    // MARK: Private

    private var context: ModelContext?
    private var timerTask: Task<Void, Never>?

    // MARK: - Lifecycle

    func bind(_ context: ModelContext) {
        self.context = context
    }

    // MARK: - Session control

    /// Begin a new session. Safe to call even if one is already active;
    /// calling it when active first resets the previous session.
    func start() {
        reset()
        isActive = true
        startDate = Date()
        startTimer()
        WorkoutLiveActivityController.start(gymName: "FitPilot AI", startedAt: startDate)
        WidgetSyncService.setWorkoutActive(true)
    }

    /// Persist the draft session as a `Workout`, save to HealthKit, then reset.
    /// Returns the newly created `Workout` so callers can react to the save.
    @discardableResult
    func finish() -> Workout? {
        guard let context, isActive else { return nil }

        let endDate = Date()
        let duration = endDate.timeIntervalSince(startDate)

        let exerciseDTOs = exercises.enumerated().map { index, draft in
            WorkoutExerciseDTO(
                id: draft.id,
                machineID: draft.machineID,
                machineName: draft.machineName,
                sets: draft.sets.enumerated().map { setIndex, draftSet in
                    WorkoutSetDTO(
                        id: draftSet.id,
                        weight: draftSet.weight,
                        repetitions: draftSet.reps,
                        timestamp: startDate.addingTimeInterval(Double(setIndex)),
                        typeRaw: draftSet.type.rawValue
                    )
                }
            )
        }

        let dto = WorkoutDTO(
            id: UUID(),
            date: startDate,
            duration: duration,
            notes: "",
            exercises: exerciseDTOs
        )

        let service = WorkoutService(context: context)
        let workout = service.persist(dto)

        // HealthKit save — fire and forget; update the stored ID on return.
        let workoutID = workout.id
        let capturedStart = startDate
        let capturedEnd = endDate
        let estimatedKcal = activeEnergyEstimate
        Task { [weak self] in
            _ = self // suppress unused-capture warning
            let hkID = await HealthKitService.shared.saveStrengthWorkout(
                start: capturedStart,
                end: capturedEnd,
                activeEnergyKcal: estimatedKcal
            )
            if let hkID {
                // Fetch fresh to avoid crossing concurrency boundaries.
                let descriptor = FetchDescriptor<Workout>(
                    predicate: #Predicate { $0.id == workoutID }
                )
                if let saved = try? context.fetch(descriptor).first {
                    saved.healthKitWorkoutID = hkID
                    try? context.save()
                }
            }
        }

        reset()
        return workout
    }

    /// Tear down any active session and timer, returning to the idle state.
    func reset() {
        stopTimer()
        isActive = false
        exercises = []
        elapsedSeconds = 0
        startDate = Date()
        Task { await WorkoutLiveActivityController.end() }
        WidgetSyncService.setWorkoutActive(false)
    }

    /// Push the current exercise + set count to the Live Activity (no-op when
    /// no session/activity is running). Elapsed time is rendered live by the
    /// widget from the start date, so only content changes need a push.
    private func syncLiveActivity() {
        guard isActive else { return }
        let totalSets = exercises.reduce(0) { $0 + $1.sets.count }
        let current = exercises.last?.machineName ?? "Warming up"
        Task {
            await WorkoutLiveActivityController.update(
                currentExercise: current,
                setsLogged: totalSets,
                planProgress: nil
            )
        }
    }

    // MARK: - Exercise management

    func addExercise(machine: Machine) {
        // Prevent duplicate machines in a single session.
        guard !exercises.contains(where: { $0.machineID == machine.id }) else { return }
        exercises.append(DraftExercise(machineID: machine.id, machineName: machine.name))
        syncLiveActivity()
    }

    /// Add a machine by UUID, fetching it from the persistent store.
    func addExerciseByID(_ machineID: UUID) {
        guard let context else { return }
        guard !exercises.contains(where: { $0.machineID == machineID }) else { return }
        let descriptor = FetchDescriptor<Machine>(
            predicate: #Predicate { $0.id == machineID }
        )
        guard let machine = try? context.fetch(descriptor).first else { return }
        exercises.append(DraftExercise(machineID: machine.id, machineName: machine.name))
        syncLiveActivity()
    }

    func removeExercise(at offsets: IndexSet) {
        exercises.remove(atOffsets: offsets)
    }

    func removeExercise(id: UUID) {
        exercises.removeAll { $0.id == id }
    }

    // MARK: - Set management

    /// Append a set to the exercise at `index`.
    func addSet(weight: Double, reps: Int, type: WorkoutSetType = .working, toExerciseAt index: Int) {
        guard index < exercises.count else { return }
        let set = DraftSet(weight: weight, reps: reps, type: type)
        exercises[index].sets.append(set)
        syncLiveActivity()
    }

    /// Duplicate the last logged set of the exercise at `index` (same weight +
    /// reps) so the user can quickly log repeated sets with one tap.
    @discardableResult
    func repeatLastSet(forExerciseAt index: Int) -> DraftSet? {
        guard index < exercises.count, let last = exercises[index].sets.last else { return nil }
        let copy = DraftSet(weight: last.weight, reps: last.reps, type: last.type)
        exercises[index].sets.append(copy)
        syncLiveActivity()
        return copy
    }

    /// Remove the last logged set from the exercise at `index`.
    func removeLastSet(fromExerciseAt index: Int) {
        guard index < exercises.count, !exercises[index].sets.isEmpty else { return }
        exercises[index].sets.removeLast()
    }

    /// Remove a specific set by ID from the exercise at `index`.
    func removeSet(id: UUID, fromExerciseAt index: Int) {
        guard index < exercises.count else { return }
        exercises[index].sets.removeAll { $0.id == id }
        syncLiveActivity()
    }

    // MARK: - Last-session passthrough

    /// Previous session data for a machine, so the active workout UI can show
    /// reference sets without knowing about `WorkoutService` directly.
    func lastSession(forMachineID machineID: UUID) -> WorkoutExercise? {
        guard let context else { return nil }
        return WorkoutService(context: context).lastSession(forMachineID: machineID)
    }

    /// Five most-recently trained machines, for the quick-pick list on the
    /// start screen.
    func recentMachines() -> [MachineRef] {
        guard let context else { return [] }
        return WorkoutService(context: context).lastTrainedMachines(limit: 5)
    }

    // MARK: - Energy estimate

    /// Rough active-energy estimate (kcal) based on total volume lifted.
    /// ~1 kcal per 10 kg of volume is a conservative heuristic.
    var activeEnergyEstimate: Double {
        let totalVolume = exercises.reduce(0.0) { total, exercise in
            total + exercise.sets.reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        }
        return totalVolume / 10.0
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                await MainActor.run { self?.elapsedSeconds += 1 }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
}
