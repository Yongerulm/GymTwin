import XCTest
import SwiftData
@testable import GymTwin

/// Verifies that SampleData.seedIfNeeded populates the expected gym structure
/// and is idempotent (a second call skips seeding).
@MainActor
final class SampleDataTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        container = PersistenceController.makeInMemoryContainer()
        context = container.mainContext
    }

    override func tearDown() async throws {
        context = nil
        container = nil
        try await super.tearDown()
    }

    // MARK: - seedIfNeeded on empty context

    func testSeedIfNeeded_onEmptyContext_returnsTrue() throws {
        // Act
        let seeded = SampleData.seedIfNeeded(context)

        // Assert
        XCTAssertTrue(seeded, "seedIfNeeded should return true when context was empty")
    }

    func testSeedIfNeeded_createsExactlyOneGym() throws {
        // Act
        SampleData.seedIfNeeded(context)
        let gyms = try context.fetch(FetchDescriptor<Gym>())

        // Assert
        XCTAssertEqual(gyms.count, 1)
        XCTAssertFalse(gyms.first!.name.isEmpty, "Gym should have a non-empty name")
    }

    func testSeedIfNeeded_createsSevenAreas() throws {
        // Act
        SampleData.seedIfNeeded(context)
        let areas = try context.fetch(FetchDescriptor<GymArea>())

        // Assert
        XCTAssertEqual(areas.count, 7, "Seed should create exactly 7 gym areas")
    }

    func testSeedIfNeeded_createsAtLeastNineMachines() throws {
        // Act
        SampleData.seedIfNeeded(context)
        let machines = try context.fetch(FetchDescriptor<Machine>())

        // Assert
        XCTAssertGreaterThanOrEqual(machines.count, 9, "Seed should create at least 9 machines")
    }

    func testSeedIfNeeded_allMachinesHaveAtLeastOneSetting() throws {
        // Act
        SampleData.seedIfNeeded(context)
        let machines = try context.fetch(FetchDescriptor<Machine>())

        // Assert
        for machine in machines {
            XCTAssertFalse(machine.settings.isEmpty, "Machine '\(machine.name)' should have at least one setting")
        }
    }

    func testSeedIfNeeded_createsAtLeastTwoHistoricalWorkouts() throws {
        // Act
        SampleData.seedIfNeeded(context)
        let workouts = try context.fetch(FetchDescriptor<Workout>())

        // Assert
        XCTAssertGreaterThanOrEqual(workouts.count, 2, "Seed should create at least 2 historical workouts")
    }

    func testSeedIfNeeded_historicalWorkoutsHaveExercisesAndSets() throws {
        // Act
        SampleData.seedIfNeeded(context)
        let workouts = try context.fetch(FetchDescriptor<Workout>())

        // Assert
        for workout in workouts {
            XCTAssertFalse(workout.exercises.isEmpty, "Seeded workout should have exercises")
            for exercise in workout.exercises {
                XCTAssertFalse(exercise.sets.isEmpty, "Seeded exercise should have sets")
            }
        }
    }

    func testSeedIfNeeded_allAreasHaveCorrectGymRelationship() throws {
        // Act
        SampleData.seedIfNeeded(context)
        let gym = try context.fetch(FetchDescriptor<Gym>()).first!
        let areas = try context.fetch(FetchDescriptor<GymArea>())

        // Assert
        for area in areas {
            XCTAssertEqual(area.gym?.id, gym.id, "Area '\(area.name)' should belong to the seeded gym")
        }
    }

    // MARK: - Idempotency

    func testSeedIfNeeded_secondCall_returnsFalse() throws {
        // Act
        let firstCall = SampleData.seedIfNeeded(context)
        let secondCall = SampleData.seedIfNeeded(context)

        // Assert
        XCTAssertTrue(firstCall, "First seed should return true")
        XCTAssertFalse(secondCall, "Second seed should return false (idempotent)")
    }

    func testSeedIfNeeded_secondCall_doesNotDuplicateData() throws {
        // Act
        SampleData.seedIfNeeded(context)
        SampleData.seedIfNeeded(context)

        let gyms = try context.fetch(FetchDescriptor<Gym>())
        let areas = try context.fetch(FetchDescriptor<GymArea>())

        // Assert — counts must not have doubled
        XCTAssertEqual(gyms.count, 1, "Second seed must not insert a duplicate gym")
        XCTAssertEqual(areas.count, 7, "Second seed must not duplicate areas")
    }

    func testSeedIfNeeded_secondCall_doesNotDuplicateMachinesOrWorkouts() throws {
        // Act
        SampleData.seedIfNeeded(context)
        let machinesAfterFirst = try context.fetch(FetchDescriptor<Machine>()).count
        let workoutsAfterFirst = try context.fetch(FetchDescriptor<Workout>()).count

        SampleData.seedIfNeeded(context)
        let machinesAfterSecond = try context.fetch(FetchDescriptor<Machine>()).count
        let workoutsAfterSecond = try context.fetch(FetchDescriptor<Workout>()).count

        // Assert
        XCTAssertEqual(machinesAfterFirst, machinesAfterSecond, "Machine count must not change on second seed")
        XCTAssertEqual(workoutsAfterFirst, workoutsAfterSecond, "Workout count must not change on second seed")
    }
}
