import Foundation
import SwiftData

/// Seeds the `Exercise` library from the bundled `exercises.json` on first
/// launch. Idempotent: it only seeds when the store holds no exercises, so it
/// is safe to call on every launch.
enum ExerciseSeeder {
    /// Seeds the exercise library if empty. Returns the number of exercises
    /// inserted (0 when already seeded or the catalog is missing).
    @discardableResult
    @MainActor
    static func seedIfNeeded(_ context: ModelContext, bundle: Bundle = .main) -> Int {
        let existing = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        guard existing == 0 else { return 0 }

        let defs = ExerciseCatalog.load(bundle: bundle)
        guard !defs.isEmpty else { return 0 }

        for def in defs {
            context.insert(def.makeModel())
        }
        try? context.save()
        return defs.count
    }
}
