import XCTest
@testable import GymTwin

/// Unit tests for `LocalMachineRepository` against the bundled `machines.json`
/// (9 machines seeded at build time into the test host bundle).
///
/// All tests are `async` because `MachineRepository` is actor-isolated and uses
/// `async throws` methods.
@MainActor
final class MachineRepositoryTests: XCTestCase {

    // MARK: - allMachines

    func testAllMachines_bundledSeed_returnsNineMachines() async throws {
        // Arrange
        let repo = LocalMachineRepository(overridesURL: nil)

        // Act
        let all = try await repo.allMachines()

        // Assert
        XCTAssertEqual(all.count, 9,
                       "The bundled machines.json contains exactly 9 machine definitions.")
    }

    // MARK: - machine(forCode:)

    func testMachineForCode_knownCode_returnsCorrectName() async throws {
        // Arrange
        let repo = LocalMachineRepository(overridesURL: nil)

        // Act
        let machine = try await repo.machine(forCode: "sscp")

        // Assert
        XCTAssertEqual(machine?.name, "Chest Press",
                       "`sscp` should resolve to the Chest Press definition.")
    }

    func testMachineForCode_unknownCode_returnsNil() async throws {
        // Arrange
        let repo = LocalMachineRepository(overridesURL: nil)

        // Act
        let machine = try await repo.machine(forCode: "zzz_unknown")

        // Assert
        XCTAssertNil(machine, "An unrecognised code should return nil, not throw.")
    }

    // MARK: - search

    func testSearch_chestQuery_containsChestPress() async throws {
        // Arrange
        let repo = LocalMachineRepository(overridesURL: nil)

        // Act
        let results = try await repo.search("chest")
        let names = results.map(\.name)

        // Assert
        XCTAssertTrue(names.contains("Chest Press"),
                      "Searching for 'chest' should include the Chest Press machine.")
    }

    func testSearch_emptyQuery_returnsAllMachines() async throws {
        // Arrange
        let repo = LocalMachineRepository(overridesURL: nil)

        // Act
        let results = try await repo.search("")

        // Assert
        XCTAssertEqual(results.count, 9,
                       "An empty search query should return all machines.")
    }

    // MARK: - upsert

    func testUpsert_newDefinition_retrievableByCode() async throws {
        // Arrange
        let repo = LocalMachineRepository(overridesURL: nil)
        let newDef = MachineDefinition(
            machineCode: "test_leg_press",
            name: "Leg Press",
            manufacturer: "Acme",
            category: "Legs",
            primaryMuscles: ["Quadriceps"]
        )

        // Act
        try await repo.upsert(newDef)
        let retrieved = try await repo.machine(forCode: "test_leg_press")

        // Assert
        XCTAssertNotNil(retrieved,
                        "An upserted definition must be retrievable by its machine code.")
        XCTAssertEqual(retrieved?.name, "Leg Press",
                       "The retrieved definition should carry the upserted name.")
    }

    func testUpsert_existingCode_overwritesDefinition() async throws {
        // Arrange — upsert a replacement for the known Chest Press entry
        let repo = LocalMachineRepository(overridesURL: nil)
        let updated = MachineDefinition(
            machineCode: "sscp",
            name: "Chest Press (Updated)",
            category: "Push"
        )

        // Act
        try await repo.upsert(updated)
        let retrieved = try await repo.machine(forCode: "sscp")

        // Assert
        XCTAssertEqual(retrieved?.name, "Chest Press (Updated)",
                       "Upserting with an existing code should overwrite the previous definition.")
    }
}
