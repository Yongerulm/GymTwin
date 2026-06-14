import Foundation
import SwiftData

/// A single training session. Created on iPhone or Apple Watch, it groups the
/// exercises performed and is mirrored into Apple Health on completion.
@Model
final class Workout {
    @Attribute(.unique) var id: UUID
    var date: Date
    /// Total session duration in seconds.
    var duration: TimeInterval
    var notes: String
    /// UUID of the `HKWorkout` written to HealthKit, if any. Extension point
    /// for de-duplication and future read-back; never required for the app
    /// to function offline.
    var healthKitWorkoutID: UUID?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
    var exercises: [WorkoutExercise]

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        duration: TimeInterval = 0,
        notes: String = "",
        healthKitWorkoutID: UUID? = nil
    ) {
        self.id = id
        self.date = date
        self.duration = duration
        self.notes = notes
        self.healthKitWorkoutID = healthKitWorkoutID
        self.exercises = []
    }

    /// Exercises in the order they were performed.
    var sortedExercises: [WorkoutExercise] {
        exercises.sorted { $0.sortIndex < $1.sortIndex }
    }

    /// Total number of sets logged across all exercises.
    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }

    /// Total volume (sum of weight × reps) for the session.
    var totalVolume: Double {
        exercises.reduce(0) { partial, exercise in
            partial + exercise.sets.reduce(0) { $0 + ($1.weight * Double($1.repetitions)) }
        }
    }
}
