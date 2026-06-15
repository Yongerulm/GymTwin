import Foundation
import SwiftData

/// A canonical exercise from the bundled exercise library (1000+ movements).
///
/// This is *reference data*, seeded once from `exercises.json` and then queried
/// for browsing, search and plan building. It is distinct from `WorkoutExercise`
/// (a logged exercise inside a session). Kept in SwiftData so it is queryable
/// with `@Query` and can later be linked from plans and workouts.
@Model
final class Exercise {
    /// Stable slug identifier from the source catalog, e.g. "barbell-bench-press".
    @Attribute(.unique) var catalogID: String
    var name: String

    /// Muscle taxonomy (normalised vocabulary, e.g. "chest", "triceps").
    var primaryMuscles: [String]
    var secondaryMuscles: [String]

    /// Equipment bucket, e.g. "barbell", "dumbbell", "machine", "body only".
    var equipment: String?
    /// Catalog category, e.g. "strength", "cardio", "stretching".
    var category: String
    /// Movement mechanic: "compound" or "isolation" (nil when unknown).
    var mechanic: String?
    /// Difficulty: "beginner", "intermediate", or "expert".
    var level: String
    /// Force vector: "push", "pull", or "static" (nil when unknown).
    var force: String?
    /// Step-by-step coaching cues.
    var instructions: [String]

    init(
        catalogID: String,
        name: String,
        primaryMuscles: [String] = [],
        secondaryMuscles: [String] = [],
        equipment: String? = nil,
        category: String = "strength",
        mechanic: String? = nil,
        level: String = "intermediate",
        force: String? = nil,
        instructions: [String] = []
    ) {
        self.catalogID = catalogID
        self.name = name
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.equipment = equipment
        self.category = category
        self.mechanic = mechanic
        self.level = level
        self.force = force
        self.instructions = instructions
    }

    /// All muscles, primary first, for display and analytics grouping.
    var allMuscles: [String] { primaryMuscles + secondaryMuscles }

    /// A concise muscle summary, e.g. "Chest · Triceps".
    var muscleSummary: String {
        primaryMuscles.map { $0.capitalized }.joined(separator: " · ")
    }
}
