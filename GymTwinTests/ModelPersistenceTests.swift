import XCTest
import SwiftData
@testable import GymTwin

/// Verifies that SwiftData relationships, cascade deletes, and the
/// intentional non-cascade between Machine and WorkoutExercise all behave
/// correctly against an in-memory container.
@MainActor
final class ModelPersistenceTests: XCTestCase {

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

    // MARK: - Graph insertion

    func testInsertGymAreaMachineSetting_graphFetchesIntact() throws {
        // Arrange
        let gym = Gym(name: "Test Gym", location: "HQ")
        context.insert(gym)

        let area = GymArea(name: "Chest", sortIndex: 0)
        area.gym = gym
        context.insert(area)

        let machine = Machine(name: "Chest Press", category: "Push", sortIndex: 0)
        machine.area = area
        context.insert(machine)

        let setting = MachineSetting(title: "Seat Height", value: "5", sortIndex: 0)
        setting.machine = machine
        machine.settings.append(setting)

        try context.save()

        // Act
        let gyms = try context.fetch(FetchDescriptor<Gym>())
        let areas = try context.fetch(FetchDescriptor<GymArea>())
        let machines = try context.fetch(FetchDescriptor<Machine>())
        let settings = try context.fetch(FetchDescriptor<MachineSetting>())

        // Assert
        XCTAssertEqual(gyms.count, 1)
        XCTAssertEqual(areas.count, 1)
        XCTAssertEqual(machines.count, 1)
        XCTAssertEqual(settings.count, 1)
        XCTAssertEqual(gyms.first?.sortedAreas.first?.name, "Chest")
        XCTAssertEqual(gyms.first?.sortedAreas.first?.sortedMachines.first?.name, "Chest Press")
        XCTAssertEqual(machines.first?.sortedSettings.first?.title, "Seat Height")
    }

    func testInsertWorkoutExerciseSet_graphFetchesIntact() throws {
        // Arrange
        let workout = Workout(date: Date(), duration: 3600, notes: "Good session")
        context.insert(workout)

        let exercise = WorkoutExercise(machineID: UUID(), machineName: "Lat Pulldown", sortIndex: 0)
        exercise.workout = workout
        workout.exercises.append(exercise)

        let set1 = WorkoutSet(weight: 60, repetitions: 10, sortIndex: 0)
        let set2 = WorkoutSet(weight: 65, repetitions: 8, sortIndex: 1)
        set1.exercise = exercise
        set2.exercise = exercise
        exercise.sets.append(contentsOf: [set1, set2])

        try context.save()

        // Act
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        let exercises = try context.fetch(FetchDescriptor<WorkoutExercise>())
        let sets = try context.fetch(FetchDescriptor<WorkoutSet>())

        // Assert
        XCTAssertEqual(workouts.count, 1)
        XCTAssertEqual(exercises.count, 1)
        XCTAssertEqual(sets.count, 2)
        XCTAssertEqual(workouts.first?.totalSets, 2)
        XCTAssertEqual(workouts.first?.sortedExercises.first?.machineName, "Lat Pulldown")
    }

    // MARK: - Gym cascade delete

    func testDeleteGym_cascadesAreasAndMachines() throws {
        // Arrange
        let gym = Gym(name: "Cascade Gym", location: "")
        context.insert(gym)

        let area = GymArea(name: "Back", sortIndex: 0)
        area.gym = gym
        context.insert(area)

        let machine = Machine(name: "Lat Pulldown", category: "Pull", sortIndex: 0)
        machine.area = area
        context.insert(machine)

        let setting = MachineSetting(title: "Knee Pad", value: "7", sortIndex: 0)
        setting.machine = machine
        machine.settings.append(setting)

        try context.save()

        // Act — delete the root gym
        context.delete(gym)
        try context.save()

        // Assert — all dependent rows removed
        let gyms = try context.fetch(FetchDescriptor<Gym>())
        let areas = try context.fetch(FetchDescriptor<GymArea>())
        let machines = try context.fetch(FetchDescriptor<Machine>())
        let settings = try context.fetch(FetchDescriptor<MachineSetting>())

        XCTAssertTrue(gyms.isEmpty, "Gym should be deleted")
        XCTAssertTrue(areas.isEmpty, "GymArea cascade delete should fire")
        XCTAssertTrue(machines.isEmpty, "Machine cascade delete should fire")
        XCTAssertTrue(settings.isEmpty, "MachineSetting cascade delete should fire")
    }

    // MARK: - Workout cascade delete

    func testDeleteWorkout_cascadesExercisesAndSets() throws {
        // Arrange
        let workout = Workout(date: Date(), duration: 1800, notes: "")
        context.insert(workout)

        let exercise = WorkoutExercise(machineID: UUID(), machineName: "Leg Press", sortIndex: 0)
        exercise.workout = workout
        workout.exercises.append(exercise)

        let set = WorkoutSet(weight: 100, repetitions: 12, sortIndex: 0)
        set.exercise = exercise
        exercise.sets.append(set)

        try context.save()

        // Act
        context.delete(workout)
        try context.save()

        // Assert
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        let exercises = try context.fetch(FetchDescriptor<WorkoutExercise>())
        let sets = try context.fetch(FetchDescriptor<WorkoutSet>())

        XCTAssertTrue(workouts.isEmpty, "Workout should be deleted")
        XCTAssertTrue(exercises.isEmpty, "WorkoutExercise cascade delete should fire")
        XCTAssertTrue(sets.isEmpty, "WorkoutSet cascade delete should fire")
    }

    // MARK: - Machine delete does NOT remove WorkoutExercise

    func testDeleteMachine_doesNotDeleteWorkoutExerciseRows() throws {
        // Arrange — machine and a historical exercise referencing it by ID
        let machineID = UUID()
        let machine = Machine(id: machineID, name: "Bicep Curl", category: "Arms", sortIndex: 0)
        context.insert(machine)

        let workout = Workout(date: Date(), duration: 900, notes: "")
        context.insert(workout)

        let exercise = WorkoutExercise(machineID: machineID, machineName: "Bicep Curl", sortIndex: 0)
        exercise.workout = workout
        workout.exercises.append(exercise)

        let set = WorkoutSet(weight: 20, repetitions: 15, sortIndex: 0)
        set.exercise = exercise
        exercise.sets.append(set)

        try context.save()

        // Act — delete only the machine
        context.delete(machine)
        try context.save()

        // Assert — historical workout data is untouched
        let machines = try context.fetch(FetchDescriptor<Machine>())
        let exercises = try context.fetch(FetchDescriptor<WorkoutExercise>())
        let sets = try context.fetch(FetchDescriptor<WorkoutSet>())

        XCTAssertTrue(machines.isEmpty, "Machine should be deleted")
        XCTAssertEqual(exercises.count, 1, "WorkoutExercise must NOT be cascade-deleted with Machine")
        XCTAssertEqual(sets.count, 1, "WorkoutSet must NOT be cascade-deleted through Machine")
        XCTAssertEqual(exercises.first?.machineID, machineID, "machineID value-reference should be intact")
        XCTAssertEqual(exercises.first?.machineName, "Bicep Curl", "Snapshot name should be intact")
    }

    // MARK: - sortedAreas / sortedMachines ordering

    func testSortedAreas_respectsSortIndex() throws {
        // Arrange
        let gym = Gym(name: "Order Gym", location: "")
        context.insert(gym)

        let a2 = GymArea(name: "Legs", sortIndex: 2); a2.gym = gym; context.insert(a2)
        let a0 = GymArea(name: "Chest", sortIndex: 0); a0.gym = gym; context.insert(a0)
        let a1 = GymArea(name: "Back", sortIndex: 1); a1.gym = gym; context.insert(a1)

        try context.save()

        // Act
        let fetched = try context.fetch(FetchDescriptor<Gym>())

        // Assert
        let names = fetched.first?.sortedAreas.map(\.name) ?? []
        XCTAssertEqual(names, ["Chest", "Back", "Legs"])
    }
}
