import Foundation

/// A canonical exercise record as stored in the bundled `exercises.json`
/// library. This is the on-disk / wire shape; `Exercise` is the SwiftData model
/// it seeds. `Sendable` + `Codable` value type so it crosses isolation
/// boundaries cleanly.
struct ExerciseDefinition: Codable, Identifiable, Hashable, Sendable {
    /// Stable slug identifier, e.g. "barbell-bench-press".
    let id: String
    let name: String
    var primaryMuscles: [String]
    var secondaryMuscles: [String]
    var equipment: String?
    var category: String
    var mechanic: String?
    var level: String
    var force: String?
    var instructions: [String]

    init(
        id: String,
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
        self.id = id
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

    /// Builds the SwiftData model this definition seeds.
    @MainActor
    func makeModel() -> Exercise {
        Exercise(
            catalogID: id,
            name: name,
            primaryMuscles: primaryMuscles,
            secondaryMuscles: secondaryMuscles,
            equipment: equipment,
            category: category,
            mechanic: mechanic,
            level: level,
            force: force,
            instructions: instructions
        )
    }
}
