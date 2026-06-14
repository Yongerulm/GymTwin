import XCTest
import SwiftData
@testable import GymTwin

/// Verifies that WorkoutDTO and MachineDTO survive JSON encode/decode round-trips
/// and that model→DTO→model conversion preserves all semantically important fields.
@MainActor
final class WatchPayloadsTests: XCTestCase {

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

    // MARK: - WorkoutDTO JSON round-trip

    func testWorkoutDTO_JSONRoundTrip_preservesAllFields() throws {
        // Arrange — build a Workout model graph
        let workoutID = UUID()
        let exerciseID = UUID()
        let setID = UUID()
        let machineID = UUID()
        let referenceDate = Date(timeIntervalSinceReferenceDate: 800_000_000)

        let workout = Workout(id: workoutID, date: referenceDate, duration: 3600, notes: "Heavy day")
        context.insert(workout)

        let exercise = WorkoutExercise(id: exerciseID, machineID: machineID, machineName: "Chest Press", sortIndex: 0)
        exercise.workout = workout
        workout.exercises.append(exercise)

        let set = WorkoutSet(id: setID, weight: 80.0, repetitions: 8, timestamp: referenceDate, sortIndex: 0)
        set.exercise = exercise
        exercise.sets.append(set)

        try? context.save()

        // Act — model → DTO → JSON → DTO → model
        let dto = WorkoutDTO(workout: workout)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(dto)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WorkoutDTO.self, from: data)

        // Assert DTO fields survive encoding
        XCTAssertEqual(decoded.id, workoutID)
        XCTAssertEqual(decoded.duration, 3600)
        XCTAssertEqual(decoded.notes, "Heavy day")
        XCTAssertEqual(decoded.exercises.count, 1)
        XCTAssertEqual(decoded.exercises.first?.id, exerciseID)
        XCTAssertEqual(decoded.exercises.first?.machineID, machineID)
        XCTAssertEqual(decoded.exercises.first?.machineName, "Chest Press")
        XCTAssertEqual(decoded.exercises.first?.sets.count, 1)
        XCTAssertEqual(decoded.exercises.first?.sets.first?.id, setID)
        XCTAssertEqual(decoded.exercises.first?.sets.first?.weight, 80.0)
        XCTAssertEqual(decoded.exercises.first?.sets.first?.repetitions, 8)
    }

    func testWorkoutDTO_makeWorkout_preservesWeightRepsAndIDs() throws {
        // Arrange
        let setID = UUID()
        let machineID = UUID()
        let dto = WorkoutDTO(
            id: UUID(),
            date: Date(),
            duration: 1800,
            notes: "From watch",
            exercises: [
                WorkoutExerciseDTO(
                    id: UUID(),
                    machineID: machineID,
                    machineName: "Leg Press",
                    sets: [
                        WorkoutSetDTO(id: setID, weight: 120.0, repetitions: 12, timestamp: Date()),
                        WorkoutSetDTO(id: UUID(), weight: 130.0, repetitions: 10, timestamp: Date())
                    ]
                )
            ]
        )

        // Act
        let workout = dto.makeWorkout()

        // Assert
        XCTAssertEqual(workout.id, dto.id)
        XCTAssertEqual(workout.notes, "From watch")
        XCTAssertEqual(workout.sortedExercises.count, 1)
        let ex = workout.sortedExercises.first!
        XCTAssertEqual(ex.machineID, machineID)
        XCTAssertEqual(ex.machineName, "Leg Press")
        XCTAssertEqual(ex.sortedSets.count, 2)
        XCTAssertEqual(ex.sortedSets.first?.id, setID)
        XCTAssertEqual(ex.sortedSets.first?.weight, 120.0)
        XCTAssertEqual(ex.sortedSets.first?.repetitions, 12)
        XCTAssertEqual(ex.sortedSets.last?.weight, 130.0)
    }

    func testWorkoutDTO_fullCycle_modelToDTOToModelPreservesIDs() throws {
        // Arrange — full Workout model
        let workoutID = UUID()
        let machineID = UUID()
        let setID = UUID()
        let now = Date()

        let workout = Workout(id: workoutID, date: now, duration: 2700, notes: "Cycle test")
        context.insert(workout)

        let exercise = WorkoutExercise(machineID: machineID, machineName: "Row", sortIndex: 0)
        exercise.workout = workout
        workout.exercises.append(exercise)

        let set = WorkoutSet(id: setID, weight: 55.0, repetitions: 10, timestamp: now, sortIndex: 0)
        set.exercise = exercise
        exercise.sets.append(set)

        try? context.save()

        // Act — full cycle
        let dto = WorkoutDTO(workout: workout)
        let restored = dto.makeWorkout()

        // Assert
        XCTAssertEqual(restored.id, workoutID)
        XCTAssertEqual(restored.sortedExercises.first?.machineID, machineID)
        XCTAssertEqual(restored.sortedExercises.first?.sortedSets.first?.id, setID)
        XCTAssertEqual(restored.sortedExercises.first?.sortedSets.first?.weight, 55.0)
        XCTAssertEqual(restored.sortedExercises.first?.sortedSets.first?.repetitions, 10)
    }

    // MARK: - MachineDTO mapping

    func testMachineDTO_mapsNameCategoryNotesAndAreaName() throws {
        // Arrange
        let gym = Gym(name: "My Gym", location: "")
        context.insert(gym)

        let area = GymArea(name: "Shoulders", sortIndex: 0)
        area.gym = gym
        context.insert(area)

        let machine = Machine(name: "Shoulder Press", category: "Push", notes: "Lower seat", sortIndex: 0)
        machine.area = area
        context.insert(machine)

        let s0 = MachineSetting(title: "Seat Height", value: "5", sortIndex: 0)
        let s1 = MachineSetting(title: "Handle Width", value: "2", sortIndex: 1)
        s0.machine = machine; s1.machine = machine
        machine.settings.append(contentsOf: [s0, s1])

        try? context.save()

        // Act
        let dto = MachineDTO(machine: machine)

        // Assert
        XCTAssertEqual(dto.id, machine.id)
        XCTAssertEqual(dto.name, "Shoulder Press")
        XCTAssertEqual(dto.category, "Push")
        XCTAssertEqual(dto.notes, "Lower seat")
        XCTAssertEqual(dto.areaName, "Shoulders")
        XCTAssertEqual(dto.settings.count, 2)
        XCTAssertEqual(dto.settings.first?.title, "Seat Height")
        XCTAssertEqual(dto.settings.first?.value, "5")
        XCTAssertEqual(dto.settings.last?.title, "Handle Width")
    }

    func testMachineDTO_areaName_emptyWhenNoArea() throws {
        // Arrange
        let machine = Machine(name: "Free Weight", category: "Accessory", sortIndex: 0)
        context.insert(machine)
        try? context.save()

        // Act
        let dto = MachineDTO(machine: machine)

        // Assert
        XCTAssertEqual(dto.areaName, "", "areaName should be empty string when machine has no area")
    }

    func testMachineDTO_settingsOrder_matchesSortIndex() throws {
        // Arrange
        let machine = Machine(name: "Cable", category: "Cable", sortIndex: 0)
        context.insert(machine)

        // Insert in reverse order intentionally
        let s2 = MachineSetting(title: "C", value: "3", sortIndex: 2)
        let s0 = MachineSetting(title: "A", value: "1", sortIndex: 0)
        let s1 = MachineSetting(title: "B", value: "2", sortIndex: 1)
        s2.machine = machine; s0.machine = machine; s1.machine = machine
        machine.settings.append(contentsOf: [s2, s0, s1])

        try? context.save()

        // Act
        let dto = MachineDTO(machine: machine)

        // Assert — sortedSettings drives the mapping
        XCTAssertEqual(dto.settings.map(\.title), ["A", "B", "C"])
    }
}
