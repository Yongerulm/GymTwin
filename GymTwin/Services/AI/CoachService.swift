import Foundation
import SwiftData

/// Bridges the pure `AIWorkoutCoach` to live SwiftData history. Call sites ask
/// for a recommendation by machine; this builds the `PerformanceSample` series
/// from `WorkoutService` and delegates to the coach. Swap `coach` to upgrade
/// the whole app to Foundation Models / cloud later.
@MainActor
struct CoachService {
    let context: ModelContext
    var coach: AIWorkoutCoach = DeterministicWorkoutCoach()

    init(context: ModelContext, coach: AIWorkoutCoach = DeterministicWorkoutCoach()) {
        self.context = context
        self.coach = coach
    }

    /// Performance history for a machine, oldest → newest, one sample per
    /// session (the heaviest set of that session).
    func history(forMachineID machineID: UUID) -> [PerformanceSample] {
        let service = WorkoutService(context: context)
        // history(...) returns exercises newest-first; reverse to oldest-first.
        return service.history(forMachineID: machineID).reversed().compactMap { exercise in
            guard let top = exercise.sortedSets.max(by: { $0.weight < $1.weight }) else { return nil }
            let date = exercise.workout?.date ?? Date()
            return PerformanceSample(weight: top.weight, reps: top.repetitions,
                                     sets: exercise.sets.count, date: date)
        }
    }

    func nextSet(forMachineID machineID: UUID, goal: TrainingGoal) -> SetRecommendation {
        coach.nextSet(history: history(forMachineID: machineID), goal: goal)
    }

    func progression(forMachineID machineID: UUID, goal: TrainingGoal) -> ProgressionAdvice {
        coach.evaluateProgression(history: history(forMachineID: machineID), targetReps: goal.targetReps)
    }

    func deload(forMachineID machineID: UUID) -> DeloadSignal {
        coach.detectDeload(history: history(forMachineID: machineID))
    }

    func generatePlan(goal: TrainingGoal, daysPerWeek: Int, available: [MachineDefinition]) -> TrainingPlan {
        coach.generatePlan(goal: goal, daysPerWeek: daysPerWeek, available: available)
    }
}
