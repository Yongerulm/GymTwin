import Foundation
import SwiftData

/// A single set: a weight lifted for a number of repetitions, e.g. 55 kg × 12.
@Model
final class WorkoutSet {
    @Attribute(.unique) var id: UUID
    /// Weight in kilograms.
    var weight: Double
    var repetitions: Int
    var timestamp: Date
    var sortIndex: Int

    /// Owning exercise. Plain back-reference; cascade lives on `WorkoutExercise.sets`.
    var exercise: WorkoutExercise?

    init(
        id: UUID = UUID(),
        weight: Double,
        repetitions: Int,
        timestamp: Date = Date(),
        sortIndex: Int = 0
    ) {
        self.id = id
        self.weight = weight
        self.repetitions = repetitions
        self.timestamp = timestamp
        self.sortIndex = sortIndex
    }

    /// Volume contributed by this set (weight × reps).
    var volume: Double {
        weight * Double(repetitions)
    }
}
