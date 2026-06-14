import Foundation
import SwiftData

/// A reference to a machine the user trained, with the date it was last used.
struct MachineRef: Identifiable, Hashable {
    let id: UUID
    let name: String
    let lastTrained: Date
}

/// Aggregate training statistics for the dashboard.
struct TrainingStatistics: Equatable {
    var totalWorkouts: Int = 0
    var totalSets: Int = 0
    var totalVolume: Double = 0
    var workoutsThisWeek: Int = 0
    var currentStreakDays: Int = 0
    /// Total logged training time across all workouts, in seconds.
    var totalDuration: TimeInterval = 0
}

/// The analytics + persistence brain for workouts. All derived values
/// (personal records, last session, statistics) are computed from the stored
/// workouts rather than duplicated into separate state.
@MainActor
struct WorkoutService {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Queries

    /// Most recent workouts, newest first.
    func recentWorkouts(limit: Int = 5) -> [Workout] {
        var descriptor = FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func allWorkouts() -> [Workout] {
        let descriptor = FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Workouts whose date falls on the current calendar day.
    func todaysWorkouts() -> [Workout] {
        let calendar = Calendar.current
        return allWorkouts().filter { calendar.isDateInToday($0.date) }
    }

    /// All exercises performed on a machine, newest first.
    func history(forMachineID machineID: UUID) -> [WorkoutExercise] {
        let descriptor = FetchDescriptor<WorkoutExercise>(
            predicate: #Predicate { $0.machineID == machineID }
        )
        let exercises = (try? context.fetch(descriptor)) ?? []
        return exercises.sorted { lhs, rhs in
            (lhs.workout?.date ?? .distantPast) > (rhs.workout?.date ?? .distantPast)
        }
    }

    /// The most recent exercise performed on a machine, for "last session"
    /// comparison while training.
    func lastSession(forMachineID machineID: UUID) -> WorkoutExercise? {
        history(forMachineID: machineID).first
    }

    /// The heaviest single set ever logged on a machine (tie-break: more reps).
    func personalRecord(forMachineID machineID: UUID) -> WorkoutSet? {
        history(forMachineID: machineID)
            .flatMap(\.sets)
            .max { lhs, rhs in
                if lhs.weight == rhs.weight { return lhs.repetitions < rhs.repetitions }
                return lhs.weight < rhs.weight
            }
    }

    /// Distinct machines trained most recently, newest first.
    func lastTrainedMachines(limit: Int = 5) -> [MachineRef] {
        var seen = Set<UUID>()
        var refs: [MachineRef] = []
        for workout in allWorkouts() {
            for exercise in workout.sortedExercises where !seen.contains(exercise.machineID) {
                seen.insert(exercise.machineID)
                refs.append(MachineRef(id: exercise.machineID, name: exercise.machineName, lastTrained: workout.date))
                if refs.count >= limit { return refs }
            }
        }
        return refs
    }

    // MARK: - Statistics

    func statistics() -> TrainingStatistics {
        let workouts = allWorkouts()
        var stats = TrainingStatistics()
        stats.totalWorkouts = workouts.count
        stats.totalSets = workouts.reduce(0) { $0 + $1.totalSets }
        stats.totalVolume = workouts.reduce(0) { $0 + $1.totalVolume }
        stats.totalDuration = workouts.reduce(0) { $0 + $1.duration }

        let calendar = Calendar.current
        if let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start {
            stats.workoutsThisWeek = workouts.filter { $0.date >= weekStart }.count
        }
        stats.currentStreakDays = currentStreak(workouts: workouts, calendar: calendar)
        return stats
    }

    /// Counts consecutive calendar days (ending today or yesterday) with at
    /// least one workout.
    private func currentStreak(workouts: [Workout], calendar: Calendar) -> Int {
        let trainedDays = Set(workouts.map { calendar.startOfDay(for: $0.date) })
        guard !trainedDays.isEmpty else { return 0 }

        var streak = 0
        var day = calendar.startOfDay(for: Date())
        // Allow the streak to "start" yesterday if today has no workout yet.
        if !trainedDays.contains(day) {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
            guard trainedDays.contains(day) else { return 0 }
        }
        while trainedDays.contains(day) {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return streak
    }

    // MARK: - Mutations

    /// Inserts a workout built from a DTO (used by both the active-workout flow
    /// and watch sync). Returns the inserted model.
    @discardableResult
    func persist(_ dto: WorkoutDTO) -> Workout {
        let workout = dto.makeWorkout()
        context.insert(workout)
        try? context.save()
        return workout
    }

    func deleteWorkout(_ workout: Workout) {
        context.delete(workout)
        try? context.save()
    }
}
