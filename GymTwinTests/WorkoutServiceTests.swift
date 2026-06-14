import XCTest
import SwiftData
@testable import GymTwin

/// Verifies WorkoutService analytics, queries, and mutations against an
/// in-memory SwiftData container.
@MainActor
final class WorkoutServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var service: WorkoutService!

    override func setUp() async throws {
        try await super.setUp()
        container = PersistenceController.makeInMemoryContainer()
        context = container.mainContext
        service = WorkoutService(context: context)
    }

    override func tearDown() async throws {
        service = nil
        context = nil
        container = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Inserts a workout with one exercise and the given sets.
    @discardableResult
    private func insertWorkout(
        date: Date,
        machineID: UUID,
        machineName: String,
        sets: [(weight: Double, reps: Int)]
    ) -> Workout {
        let workout = Workout(date: date, duration: 3600, notes: "")
        context.insert(workout)
        let exercise = WorkoutExercise(machineID: machineID, machineName: machineName, sortIndex: 0)
        exercise.workout = workout
        workout.exercises.append(exercise)
        exercise.sets = sets.enumerated().map { idx, s in
            let ws = WorkoutSet(weight: s.weight, repetitions: s.reps, timestamp: date, sortIndex: idx)
            ws.exercise = exercise
            return ws
        }
        try? context.save()
        return workout
    }

    private func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: Calendar.current.startOfDay(for: Date()))!
    }

    // MARK: - recentWorkouts ordering

    func testRecentWorkouts_returnedNewestFirst() throws {
        // Arrange
        let id = UUID()
        insertWorkout(date: daysAgo(5), machineID: id, machineName: "M", sets: [(50, 10)])
        insertWorkout(date: daysAgo(1), machineID: id, machineName: "M", sets: [(55, 10)])
        insertWorkout(date: daysAgo(3), machineID: id, machineName: "M", sets: [(52, 10)])

        // Act
        let results = service.recentWorkouts(limit: 3)

        // Assert
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results[0].date > results[1].date, "First result should be newest")
        XCTAssertTrue(results[1].date > results[2].date, "Second result should be newer than third")
    }

    func testRecentWorkouts_respectsLimit() throws {
        // Arrange
        let id = UUID()
        for i in 0..<8 { insertWorkout(date: daysAgo(i), machineID: id, machineName: "M", sets: [(40, 8)]) }

        // Act & Assert
        XCTAssertEqual(service.recentWorkouts(limit: 3).count, 3)
        XCTAssertEqual(service.recentWorkouts(limit: 5).count, 5)
    }

    // MARK: - todaysWorkouts

    func testTodaysWorkouts_onlyReturnsToday() throws {
        // Arrange
        let id = UUID()
        insertWorkout(date: Date(), machineID: id, machineName: "M", sets: [(40, 10)])
        insertWorkout(date: daysAgo(1), machineID: id, machineName: "M", sets: [(40, 10)])
        insertWorkout(date: daysAgo(2), machineID: id, machineName: "M", sets: [(40, 10)])

        // Act
        let todays = service.todaysWorkouts()

        // Assert
        XCTAssertEqual(todays.count, 1)
        XCTAssertTrue(Calendar.current.isDateInToday(todays.first!.date))
    }

    // MARK: - history / lastSession

    func testHistory_returnsOnlyMatchingMachineNewestFirst() throws {
        // Arrange
        let targetID = UUID()
        let otherId = UUID()
        insertWorkout(date: daysAgo(4), machineID: targetID, machineName: "Chest Press", sets: [(50, 10)])
        insertWorkout(date: daysAgo(2), machineID: targetID, machineName: "Chest Press", sets: [(55, 10)])
        insertWorkout(date: daysAgo(1), machineID: otherId, machineName: "Other", sets: [(30, 12)])

        // Act
        let history = service.history(forMachineID: targetID)

        // Assert
        XCTAssertEqual(history.count, 2, "Should only return exercises for targetID")
        XCTAssertTrue(history[0].workout!.date > history[1].workout!.date, "Newest first")
    }

    func testLastSession_returnsFirstHistoryEntry() throws {
        // Arrange
        let id = UUID()
        insertWorkout(date: daysAgo(5), machineID: id, machineName: "Leg Press", sets: [(100, 10)])
        insertWorkout(date: daysAgo(2), machineID: id, machineName: "Leg Press", sets: [(110, 10)])

        // Act
        let last = service.lastSession(forMachineID: id)

        // Assert
        XCTAssertNotNil(last)
        XCTAssertEqual(last?.sortedSets.first?.weight, 110, "Last session should be the most recent one")
    }

    func testLastSession_returnsNilForUnknownMachine() throws {
        // Act & Assert
        XCTAssertNil(service.lastSession(forMachineID: UUID()))
    }

    // MARK: - personalRecord

    func testPersonalRecord_returnsHeaviestSet() throws {
        // Arrange
        let id = UUID()
        insertWorkout(date: daysAgo(10), machineID: id, machineName: "Bench", sets: [(60, 10), (65, 8)])
        insertWorkout(date: daysAgo(5), machineID: id, machineName: "Bench", sets: [(70, 6), (68, 10)])

        // Act
        let pr = service.personalRecord(forMachineID: id)

        // Assert
        XCTAssertNotNil(pr)
        XCTAssertEqual(pr?.weight, 70, "PR should be the heaviest single set")
    }

    func testPersonalRecord_tieBreaksFavorMoreReps() throws {
        // Arrange — two sets at same weight, different reps
        let id = UUID()
        let w = Workout(date: Date(), duration: 0, notes: ""); context.insert(w)
        let ex = WorkoutExercise(machineID: id, machineName: "Cable", sortIndex: 0)
        ex.workout = w; w.exercises.append(ex)
        let s1 = WorkoutSet(weight: 80, repetitions: 5, sortIndex: 0); s1.exercise = ex; ex.sets.append(s1)
        let s2 = WorkoutSet(weight: 80, repetitions: 12, sortIndex: 1); s2.exercise = ex; ex.sets.append(s2)
        try? context.save()

        // Act
        let pr = service.personalRecord(forMachineID: id)

        // Assert
        XCTAssertEqual(pr?.repetitions, 12, "Tie-break should favour more reps")
    }

    func testPersonalRecord_returnsNilForUnknownMachine() throws {
        XCTAssertNil(service.personalRecord(forMachineID: UUID()))
    }

    // MARK: - lastTrainedMachines distinctness

    func testLastTrainedMachines_returnsDistinctMachinesNewestFirst() throws {
        // Arrange — machine A trained twice, machine B once
        let machineA = UUID()
        let machineB = UUID()
        insertWorkout(date: daysAgo(5), machineID: machineA, machineName: "Machine A", sets: [(40, 10)])
        insertWorkout(date: daysAgo(2), machineID: machineA, machineName: "Machine A", sets: [(42, 10)])
        insertWorkout(date: daysAgo(3), machineID: machineB, machineName: "Machine B", sets: [(50, 8)])

        // Act
        let refs = service.lastTrainedMachines(limit: 5)

        // Assert
        XCTAssertEqual(refs.count, 2, "Should deduplicate machine A")
        let ids = refs.map(\.id)
        XCTAssertTrue(ids.contains(machineA))
        XCTAssertTrue(ids.contains(machineB))
        // Machine A's most-recent training was daysAgo(2), so it should appear first
        XCTAssertEqual(refs.first?.id, machineA)
    }

    func testLastTrainedMachines_respectsLimit() throws {
        // Arrange — 6 distinct machines
        for i in 0..<6 {
            insertWorkout(date: daysAgo(i), machineID: UUID(), machineName: "M\(i)", sets: [(30, 10)])
        }

        // Act & Assert
        XCTAssertEqual(service.lastTrainedMachines(limit: 4).count, 4)
    }

    // MARK: - statistics

    func testStatistics_totalWorkoutsAndSetsAndVolume() throws {
        // Arrange
        let id = UUID()
        insertWorkout(date: daysAgo(3), machineID: id, machineName: "Press", sets: [(50, 10), (50, 10)])
        insertWorkout(date: daysAgo(1), machineID: id, machineName: "Press", sets: [(60, 8)])

        // Act
        let stats = service.statistics()

        // Assert
        XCTAssertEqual(stats.totalWorkouts, 2)
        XCTAssertEqual(stats.totalSets, 3)
        // volume: 50*10 + 50*10 + 60*8 = 1480
        XCTAssertEqual(stats.totalVolume, 1480, accuracy: 0.01)
    }

    func testStatistics_workoutsThisWeek_countsCorrectly() throws {
        // Arrange
        let id = UUID()
        insertWorkout(date: Date(), machineID: id, machineName: "X", sets: [(40, 10)])
        insertWorkout(date: daysAgo(1), machineID: id, machineName: "X", sets: [(40, 10)])
        insertWorkout(date: daysAgo(30), machineID: id, machineName: "X", sets: [(40, 10)]) // outside week

        // Act
        let stats = service.statistics()

        // Assert
        XCTAssertEqual(stats.workoutsThisWeek, 2)
    }

    func testStatistics_currentStreakDays_consecutiveDays() throws {
        // Arrange — workouts 3 days in a row ending today
        let id = UUID()
        insertWorkout(date: Date(), machineID: id, machineName: "X", sets: [(40, 10)])
        insertWorkout(date: daysAgo(1), machineID: id, machineName: "X", sets: [(40, 10)])
        insertWorkout(date: daysAgo(2), machineID: id, machineName: "X", sets: [(40, 10)])

        // Act
        let stats = service.statistics()

        // Assert
        XCTAssertEqual(stats.currentStreakDays, 3)
    }

    func testStatistics_currentStreakDays_zeroWhenNoRecentWorkout() throws {
        // Arrange — last workout was 5 days ago (gap in streak)
        let id = UUID()
        insertWorkout(date: daysAgo(5), machineID: id, machineName: "X", sets: [(40, 10)])

        // Act
        let stats = service.statistics()

        // Assert
        XCTAssertEqual(stats.currentStreakDays, 0, "Streak should be 0 when no workout today or yesterday")
    }

    func testStatistics_emptyContext_returnsZeros() throws {
        // Act
        let stats = service.statistics()

        // Assert
        XCTAssertEqual(stats.totalWorkouts, 0)
        XCTAssertEqual(stats.totalSets, 0)
        XCTAssertEqual(stats.totalVolume, 0)
        XCTAssertEqual(stats.workoutsThisWeek, 0)
        XCTAssertEqual(stats.currentStreakDays, 0)
    }

    // MARK: - persist(dto) round-trip

    func testPersistDTO_roundTrip_workoutStoredAndFetchable() throws {
        // Arrange
        let machineID = UUID()
        let setID = UUID()
        let dto = WorkoutDTO(
            id: UUID(),
            date: daysAgo(1),
            duration: 2700,
            notes: "Watch sync",
            exercises: [
                WorkoutExerciseDTO(
                    id: UUID(),
                    machineID: machineID,
                    machineName: "Row Machine",
                    sets: [
                        WorkoutSetDTO(id: setID, weight: 75, repetitions: 9, timestamp: daysAgo(1))
                    ]
                )
            ]
        )

        // Act
        let inserted = service.persist(dto)

        // Assert
        let all = service.allWorkouts()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(inserted.id, dto.id)
        XCTAssertEqual(inserted.notes, "Watch sync")
        XCTAssertEqual(inserted.sortedExercises.first?.machineID, machineID)
        XCTAssertEqual(inserted.sortedExercises.first?.sortedSets.first?.id, setID)
        XCTAssertEqual(inserted.sortedExercises.first?.sortedSets.first?.weight, 75)
    }

    // MARK: - deleteWorkout

    func testDeleteWorkout_removesFromStore() throws {
        // Arrange
        let id = UUID()
        insertWorkout(date: Date(), machineID: id, machineName: "X", sets: [(50, 10)])
        let workout = service.allWorkouts().first!

        // Act
        service.deleteWorkout(workout)

        // Assert
        XCTAssertTrue(service.allWorkouts().isEmpty)
    }
}
