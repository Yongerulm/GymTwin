import Foundation
import SwiftData

/// One machine's worth of work inside a `Workout`. The machine is referenced by
/// value (`machineID` + `machineName`) rather than by SwiftData relationship so
/// that deleting a machine never corrupts or erases historical workouts.
@Model
final class WorkoutExercise {
    @Attribute(.unique) var id: UUID
    /// The `Machine.id` this exercise was performed on. May point to a machine
    /// that has since been deleted.
    var machineID: UUID
    /// Snapshot of the machine name at the time of training, so history stays
    /// readable even after a rename or deletion.
    var machineName: String
    var sortIndex: Int

    /// Owning workout. Plain back-reference; cascade lives on `Workout.exercises`.
    var workout: Workout?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise)
    var sets: [WorkoutSet]

    init(
        id: UUID = UUID(),
        machineID: UUID,
        machineName: String,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.machineID = machineID
        self.machineName = machineName
        self.sortIndex = sortIndex
        self.sets = []
    }

    /// Sets in the order they were performed.
    var sortedSets: [WorkoutSet] {
        sets.sorted { $0.sortIndex < $1.sortIndex }
    }

    /// Heaviest single set weight in this exercise, used for quick PR display.
    var topWeight: Double {
        sets.map(\.weight).max() ?? 0
    }
}
