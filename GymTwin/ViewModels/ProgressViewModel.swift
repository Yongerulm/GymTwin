import Foundation
import SwiftData

/// Analytics state for the Progress tab.
/// Derives all values from stored workouts via WorkoutService — no duplicate
/// state. bind(_:) is called once from the view's .task modifier; refresh()
/// can be called on every onAppear.
@Observable @MainActor
final class ProgressViewModel {

    // MARK: - Published state

    private(set) var statistics: TrainingStatistics = TrainingStatistics()

    /// Weekly volume for the last ~8 weeks, oldest first, for the bar chart.
    private(set) var weeklyVolume: [(weekLabel: String, volume: Double)] = []

    /// Personal records per recently-trained machine, for the PR list.
    private(set) var personalRecords: [(machineName: String, bestSet: WorkoutSet)] = []

    /// Volume grouped by muscle area, sorted descending, for balance bars.
    private(set) var muscleBalance: [(area: String, volume: Double)] = []

    /// Recent workouts for the history list, newest first.
    private(set) var recentWorkouts: [Workout] = []

    // MARK: - Recovery & Health highlights

    /// Deterministic recovery score 0–100.
    private(set) var recoveryScore: Int = 0

    /// Today's step count, nil when HealthKit unavailable or not yet loaded.
    private(set) var steps: Int?

    /// Last-night sleep in hours, nil when unavailable.
    private(set) var sleepHours: Double?

    /// Most-recent resting heart rate in bpm (integer), nil when unavailable.
    private(set) var restingHR: Int?

    /// Most-recent VO₂ max in ml/(kg·min), nil when unavailable.
    private(set) var vo2Max: Double?

    /// Heart-rate variability (SDNN, ms), nil when unavailable.
    private(set) var hrv: Double?

    /// HRV-led daily readiness score 0–100.
    private(set) var readiness: Int = 0

    /// Banded readiness, for the dashboard recommendation line.
    var readinessBand: ReadinessBand { ReadinessBand.from(readiness) }

    // MARK: - Internal

    private var context: ModelContext?

    // MARK: - Bind

    func bind(_ context: ModelContext) {
        self.context = context
        refresh()
        Task { await refreshHealth() }
    }

    // MARK: - Refresh (sync — workout data)

    func refresh() {
        guard let context else { return }
        let service = WorkoutService(context: context)
        let workouts = service.allWorkouts()

        statistics = service.statistics()
        recentWorkouts = Array(workouts.prefix(20))
        weeklyVolume = buildWeeklyVolume(from: workouts)
        personalRecords = buildPersonalRecords(service: service)
        muscleBalance = buildMuscleBalance(from: workouts, context: context)
        updateRecoveryScore()
    }

    // MARK: - Health refresh (async — HealthKit reads)

    func refreshHealth() async {
        let hk = HealthKitService.shared
        guard hk.isAvailable else { return }
        await hk.requestAuthorization()

        async let stepsResult = hk.latestSteps()
        async let sleepResult = hk.lastNightSleepHours()
        async let restResult  = hk.restingHeartRate()
        async let hrvResult   = hk.latestHRV()
        async let vo2Result   = hk.latestVO2Max()

        let (s, sl, rhr, h, v) = await (stepsResult, sleepResult, restResult, hrvResult, vo2Result)
        steps      = s
        sleepHours = sl
        restingHR  = rhr.map { Int($0.rounded()) }
        hrv        = h
        vo2Max     = v
        updateRecoveryScore()
    }

    // MARK: - Recovery score

    private func updateRecoveryScore() {
        let avgMinutes: Double? = statistics.totalWorkouts > 0
            ? (statistics.totalDuration / Double(statistics.totalWorkouts)) / 60
            : nil
        recoveryScore = RecoveryService.score(
            workoutsLast7Days: statistics.workoutsThisWeek,
            avgSessionMinutes: avgMinutes,
            sleepHours: sleepHours,
            restingHR: restingHR
        )
        readiness = RecoveryService.readiness(
            hrvMs: hrv,
            restingHR: restingHR,
            sleepHours: sleepHours,
            workoutsLast7Days: statistics.workoutsThisWeek
        )
    }

    // MARK: - Weekly volume (last 8 ISO weeks, oldest first)

    private func buildWeeklyVolume(from workouts: [Workout]) -> [(weekLabel: String, volume: Double)] {
        let calendar = Calendar.current
        let today = Date()

        // Build a map: weekStart -> totalVolume
        var volumeByWeek: [Date: Double] = [:]
        for workout in workouts {
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: workout.date) else { continue }
            let key = weekInterval.start
            volumeByWeek[key, default: 0] += workout.totalVolume
        }

        // Generate last 8 week-start dates ending this week
        var results: [(weekLabel: String, volume: Double)] = []
        let labelFormatter = DateFormatter()
        labelFormatter.dateFormat = "d MMM"

        for weekOffset in stride(from: -7, through: 0, by: 1) {
            guard
                let weekDate = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: today),
                let weekInterval = calendar.dateInterval(of: .weekOfYear, for: weekDate)
            else { continue }
            let key = weekInterval.start
            let label = labelFormatter.string(from: key)
            let volume = volumeByWeek[key] ?? 0
            results.append((weekLabel: label, volume: volume))
        }
        return results
    }

    // MARK: - Personal records (recently-trained machines, up to 8)

    private func buildPersonalRecords(service: WorkoutService) -> [(machineName: String, bestSet: WorkoutSet)] {
        let machines = service.lastTrainedMachines(limit: 8)
        return machines.compactMap { ref in
            guard let best = service.personalRecord(forMachineID: ref.id) else { return nil }
            return (machineName: ref.name, bestSet: best)
        }
    }

    // MARK: - Muscle balance (group workout exercises by machine area)

    private func buildMuscleBalance(from workouts: [Workout], context: ModelContext) -> [(area: String, volume: Double)] {
        // Build a machineID -> area name lookup from stored machines
        let machineDescriptor = FetchDescriptor<Machine>()
        let machines = (try? context.fetch(machineDescriptor)) ?? []
        var areaByMachineID: [UUID: String] = [:]
        for machine in machines {
            areaByMachineID[machine.id] = machine.area?.name ?? machine.category
        }

        var volumeByArea: [String: Double] = [:]
        for workout in workouts {
            for exercise in workout.exercises {
                let area = areaByMachineID[exercise.machineID] ?? "Other"
                let exerciseVolume = exercise.sets.reduce(0.0) { $0 + ($1.weight * Double($1.repetitions)) }
                volumeByArea[area, default: 0] += exerciseVolume
            }
        }

        return volumeByArea
            .map { (area: $0.key, volume: $0.value) }
            .sorted { $0.volume > $1.volume }
    }
}

// MARK: - Helpers

extension ProgressViewModel {
    /// The maximum volume in muscleBalance, used to normalise the progress bars.
    var maxMuscleVolume: Double {
        muscleBalance.first?.volume ?? 1
    }

    /// Total volume formatted for display (e.g. "12.4k kg" or "840 kg").
    var formattedTotalVolume: String {
        Self.formatVolume(statistics.totalVolume)
    }

    static func formatVolume(_ v: Double) -> String {
        if v >= 1_000 {
            return (v / 1_000).formatted(.number.precision(.fractionLength(1))) + "k"
        }
        return v.formatted(.number.precision(.fractionLength(0)))
    }

    /// "5 / 5" or however many workouts this week vs a soft goal of 5.
    var weeklyGoalProgress: Double {
        let goal = 5.0
        return min(Double(statistics.workoutsThisWeek) / goal, 1.0)
    }
}
