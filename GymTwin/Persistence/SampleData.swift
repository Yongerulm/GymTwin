import Foundation
import SwiftData

/// Seeds a realistic single-gym dataset on first launch so the app is never
/// empty during testing or first run. Idempotent: it only seeds when no gym
/// exists yet.
enum SampleData {
    /// Seeds the store if it is empty. Returns `true` if seeding ran.
    @discardableResult
    @MainActor
    static func seedIfNeeded(_ context: ModelContext) -> Bool {
        let existing = (try? context.fetchCount(FetchDescriptor<Gym>())) ?? 0
        guard existing == 0 else { return false }
        seed(context)
        return true
    }

    @MainActor
    static func seed(_ context: ModelContext) {
        let gym = Gym(name: "Shanghai Racket Club", location: "Shanghai")
        context.insert(gym)

        var areaIndex = 0
        func area(_ name: String) -> GymArea {
            let a = GymArea(name: name, sortIndex: areaIndex)
            areaIndex += 1
            a.gym = gym
            context.insert(a)
            return a
        }

        let chest = area("Chest")
        let back = area("Back")
        let legs = area("Legs")
        let shoulders = area("Shoulders")
        let arms = area("Arms")
        _ = area("Core")
        _ = area("Cardio")

        var machineIndex = 0
        @discardableResult
        func machine(
            _ name: String,
            category: String,
            in gymArea: GymArea,
            settings: [(String, String)]
        ) -> Machine {
            let m = Machine(name: name, category: category, sortIndex: machineIndex)
            machineIndex += 1
            m.area = gymArea
            context.insert(m)
            m.settings = settings.enumerated().map { idx, pair in
                MachineSetting(title: pair.0, value: pair.1, sortIndex: idx)
            }
            return m
        }

        let chestPress = machine(
            "Chest Press", category: "Push", in: chest,
            settings: [("Seat Height", "6"), ("Back Position", "3"), ("Handle Position", "2")]
        )
        machine(
            "Pec Deck", category: "Push", in: chest,
            settings: [("Seat Height", "4"), ("Range", "B")]
        )
        let latPull = machine(
            "Lat Pulldown", category: "Pull", in: back,
            settings: [("Seat Height", "5"), ("Knee Pad", "7")]
        )
        machine(
            "Seated Row", category: "Pull", in: back,
            settings: [("Seat Height", "3"), ("Chest Pad", "4")]
        )
        let legPress = machine(
            "Leg Press", category: "Legs", in: legs,
            settings: [("Seat Position", "5"), ("Back Angle", "2")]
        )
        machine(
            "Leg Extension", category: "Legs", in: legs,
            settings: [("Seat Depth", "4"), ("Ankle Pad", "6")]
        )
        machine(
            "Shoulder Press", category: "Push", in: shoulders,
            settings: [("Seat Height", "5"), ("Handle Width", "2")]
        )
        machine(
            "Bicep Curl", category: "Arms", in: arms,
            settings: [("Seat Height", "3"), ("Arm Pad", "4")]
        )
        machine(
            "Triceps Pushdown", category: "Arms", in: arms,
            settings: [("Cable Height", "8")]
        )

        seedHistory(context, machines: [chestPress, latPull, legPress])
        try? context.save()
    }

    /// A couple of historical sessions so the dashboard, PRs and
    /// "last session" comparisons have data immediately.
    @MainActor
    private static func seedHistory(_ context: ModelContext, machines: [Machine]) {
        let calendar = Calendar.current
        let now = Date()

        func session(daysAgo: Int, entries: [(Machine, [(Double, Int)])]) {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            let workout = Workout(date: date, duration: 45 * 60, notes: "")
            context.insert(workout)
            workout.exercises = entries.enumerated().map { exIndex, entry in
                let (machine, sets) = entry
                let exercise = WorkoutExercise(
                    machineID: machine.id,
                    machineName: machine.name,
                    sortIndex: exIndex
                )
                exercise.sets = sets.enumerated().map { setIndex, set in
                    WorkoutSet(weight: set.0, repetitions: set.1, timestamp: date, sortIndex: setIndex)
                }
                return exercise
            }
        }

        guard machines.count >= 3 else { return }
        session(daysAgo: 5, entries: [
            (machines[0], [(50, 12), (50, 11), (45, 12)]),
            (machines[1], [(55, 10), (55, 10)]),
        ])
        session(daysAgo: 2, entries: [
            (machines[0], [(55, 12), (55, 11), (50, 12)]),
            (machines[2], [(120, 10), (120, 9), (110, 12)]),
        ])
    }
}
