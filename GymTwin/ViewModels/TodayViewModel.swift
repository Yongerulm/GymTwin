import Foundation
import SwiftData

/// View model for the Today tab. Aggregates greeting text, workout state,
/// recent machines, a "next machine" suggestion, and HealthKit snapshot values.
/// Follows the bind/refresh pattern: the view calls `bind(_:)` once in `.task`,
/// then `refresh()` on every `onAppear`.
@Observable @MainActor
final class TodayViewModel {

    // MARK: - Greeting / date

    private(set) var greeting: String = ""
    private(set) var dateText: String = ""

    // MARK: - Workout state

    /// The first workout logged today, if any.
    private(set) var todaysWorkout: Workout?

    /// The most recent workout (may also be today's).
    private(set) var lastWorkout: Workout?

    /// A human-readable summary of the last workout: "5 sets · 2,340 kg".
    private(set) var lastSummary: String?

    // MARK: - Recent machines + next suggestion

    /// Up to 5 recently-trained machine references, newest first.
    private(set) var recentMachines: [MachineRef] = []

    /// The machine most overdue for a session, resolved from `recentMachines`.
    /// Falls back to the first recent machine if no date ordering yields a clear winner.
    private(set) var nextMachine: Machine?

    // MARK: - Health snapshot

    var heartRate: Int?
    var bodyWeightKg: Double?
    var activeEnergyKcal: Int?
    var lastWorkoutMinutes: Int?

    /// Today's readiness (HRV + sleep led), shown as a hero preview.
    var readiness: Int?
    var readinessTitle: String?

    // MARK: - Aggregate statistics

    private(set) var statistics: TrainingStatistics = TrainingStatistics()

    // MARK: - Internal

    private var context: ModelContext?

    // MARK: - Bind

    /// Called once from the view's `.task` modifier. Stores the context,
    /// triggers the first data load, and kicks off async HealthKit reads.
    func bind(_ context: ModelContext) {
        self.context = context
        refresh()
        Task { await loadHealthData() }
    }

    // MARK: - Refresh

    /// Recomputes all synchronous state from stored data.
    /// Call on every `onAppear` or SwiftData change notification.
    func refresh() {
        updateGreetingAndDate()
        guard let context else { return }

        let service = WorkoutService(context: context)
        statistics = service.statistics()

        let recent = service.recentWorkouts(limit: 5)
        lastWorkout = recent.first

        let calendar = Calendar.current
        todaysWorkout = recent.first(where: { calendar.isDateInToday($0.date) })

        if let last = lastWorkout {
            lastSummary = formatSummary(last)
            lastWorkoutMinutes = Int(last.duration / 60)
        } else {
            lastSummary = nil
            lastWorkoutMinutes = nil
        }

        recentMachines = service.lastTrainedMachines(limit: 5)
        nextMachine = resolveNextMachine(context: context, refs: recentMachines)
    }

    // MARK: - HealthKit (async)

    private func loadHealthData() async {
        let hk = HealthKitService.shared
        guard hk.isAvailable else { return }

        await hk.requestAuthorization()

        async let hr = hk.latestHeartRate()
        async let mass = hk.latestBodyMass()
        async let hrvV = hk.latestHRV()
        async let sleepV = hk.lastNightSleepHours()
        async let restV = hk.restingHeartRate()

        let (hrValue, massValue, hrv, sleep, rest) = await (hr, mass, hrvV, sleepV, restV)
        heartRate = hrValue.map { Int($0.rounded()) }
        bodyWeightKg = massValue

        let score = RecoveryService.readiness(
            hrvMs: hrv,
            restingHR: rest.map { Int($0.rounded()) },
            sleepHours: sleep,
            workoutsLast7Days: statistics.workoutsThisWeek
        )
        readiness = score
        readinessTitle = ReadinessBand.from(score).title
    }

    // MARK: - Private helpers

    private func updateGreetingAndDate() {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: greeting = "Good morning"
        case 12..<17: greeting = "Good afternoon"
        case 17..<21: greeting = "Good evening"
        default: greeting = "Good night"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        dateText = formatter.string(from: Date())
    }

    private func formatSummary(_ workout: Workout) -> String {
        let sets = workout.totalSets
        let vol = workout.totalVolume
        let volText: String
        if vol >= 1_000 {
            volText = (vol / 1_000).formatted(.number.precision(.fractionLength(1))) + "k kg"
        } else {
            volText = vol.formatted(.number.precision(.fractionLength(0))) + " kg"
        }
        return "\(sets) set\(sets == 1 ? "" : "s") · \(volText)"
    }

    /// Picks the machine that was trained longest ago — i.e., the most overdue.
    /// Resolves the UUID to a `Machine` model via a SwiftData fetch.
    private func resolveNextMachine(context: ModelContext, refs: [MachineRef]) -> Machine? {
        guard let mostOverdue = refs.max(by: { $0.lastTrained > $1.lastTrained }) else { return nil }
        let targetID = mostOverdue.id
        var descriptor = FetchDescriptor<Machine>(
            predicate: #Predicate { $0.id == targetID }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}
