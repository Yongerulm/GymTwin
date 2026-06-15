import Foundation

/// Loads the bundled exercise library (`exercises.json`, 1000+ movements) as
/// decoded value types. This is the read side of the seed architecture: the
/// catalog is decoded once and used to populate the `Exercise` SwiftData store.
enum ExerciseCatalog {
    /// Decodes every exercise definition from the bundled JSON.
    /// Returns an empty array (never throws) so a packaging mishap degrades
    /// gracefully to "library empty" rather than crashing the app.
    static func load(bundle: Bundle = .main) -> [ExerciseDefinition] {
        guard
            let url = bundle.url(forResource: "exercises", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let defs = try? JSONDecoder().decode([ExerciseDefinition].self, from: data)
        else { return [] }
        return defs
    }
}
