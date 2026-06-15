import XCTest
import SwiftData
@testable import GymTwin

/// Unit tests for the bundled exercise library: catalog decoding, schema
/// integrity, definition→model mapping, and idempotent seeding.
final class ExerciseLibraryTests: XCTestCase {

    // MARK: - Catalog decoding

    func testCatalog_bundledLibrary_hasAtLeast1000Exercises() throws {
        let defs = ExerciseCatalog.load()
        XCTAssertGreaterThanOrEqual(
            defs.count, 1000,
            "The bundled exercises.json must ship 1000+ exercises."
        )
    }

    func testCatalog_everyDefinition_hasUniqueIDAndName() throws {
        let defs = ExerciseCatalog.load()
        let ids = defs.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Exercise ids must be unique.")
        XCTAssertTrue(defs.allSatisfy { !$0.id.isEmpty && !$0.name.isEmpty },
                      "Every exercise needs a non-empty id and name.")
    }

    func testCatalog_everyDefinition_hasAtLeastOnePrimaryMuscle() throws {
        let defs = ExerciseCatalog.load()
        let withoutMuscle = defs.filter { $0.primaryMuscles.isEmpty }
        XCTAssertTrue(withoutMuscle.isEmpty,
                      "Every exercise should declare at least one primary muscle.")
    }

    // MARK: - Mapping

    @MainActor
    func testMakeModel_mapsAllFields() throws {
        let def = ExerciseDefinition(
            id: "barbell-bench-press",
            name: "Barbell Bench Press",
            primaryMuscles: ["chest"],
            secondaryMuscles: ["triceps", "shoulders"],
            equipment: "barbell",
            category: "strength",
            mechanic: "compound",
            level: "beginner",
            force: "push",
            instructions: ["Lie back", "Press up"]
        )

        let model = def.makeModel()

        XCTAssertEqual(model.catalogID, "barbell-bench-press")
        XCTAssertEqual(model.name, "Barbell Bench Press")
        XCTAssertEqual(model.primaryMuscles, ["chest"])
        XCTAssertEqual(model.secondaryMuscles, ["triceps", "shoulders"])
        XCTAssertEqual(model.equipment, "barbell")
        XCTAssertEqual(model.mechanic, "compound")
        XCTAssertEqual(model.level, "beginner")
        XCTAssertEqual(model.force, "push")
        XCTAssertEqual(model.instructions.count, 2)
        XCTAssertEqual(model.muscleSummary, "Chest")
    }

    // MARK: - Seeding

    @MainActor
    func testSeedIfNeeded_emptyStore_seedsThenIsIdempotent() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = container.mainContext

        let firstRun = ExerciseSeeder.seedIfNeeded(context)
        XCTAssertGreaterThanOrEqual(firstRun, 1000, "First seed inserts the full library.")

        let count = try context.fetchCount(FetchDescriptor<Exercise>())
        XCTAssertEqual(count, firstRun, "Store should hold exactly the seeded exercises.")

        let secondRun = ExerciseSeeder.seedIfNeeded(context)
        XCTAssertEqual(secondRun, 0, "Seeding is idempotent — a populated store is left untouched.")
    }
}
