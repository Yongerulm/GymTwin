import Foundation
import HealthKit

/// Clean abstraction over HealthKit. The rest of the app depends only on this
/// surface, never on `HKHealthStore` directly, which keeps HealthKit optional
/// and the app fully functional offline without it.
@MainActor
final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    /// Whether HealthKit is available on this device (false on iPad / unsupported).
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private init() {}

    // MARK: - Types

    private var typesToWrite: Set<HKSampleType> {
        var set: Set<HKSampleType> = [HKObjectType.workoutType()]
        if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            set.insert(energy)
        }
        return set
    }

    private var typesToRead: Set<HKObjectType> {
        var set = Set<HKObjectType>()
        if let hr   = HKQuantityType.quantityType(forIdentifier: .heartRate)          { set.insert(hr) }
        if let mass = HKQuantityType.quantityType(forIdentifier: .bodyMass)           { set.insert(mass) }
        if let fat  = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)  { set.insert(fat) }
        if let step = HKQuantityType.quantityType(forIdentifier: .stepCount)          { set.insert(step) }
        if let vo2  = HKQuantityType.quantityType(forIdentifier: .vo2Max)             { set.insert(vo2) }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)       { set.insert(sleep) }
        return set
    }

    // MARK: - Authorization

    /// Requests read/write authorization. Returns `true` if the request
    /// completed (not whether the user granted every type — HealthKit hides
    /// read permissions by design).
    @discardableResult
    func requestAuthorization() async -> Bool {
        // Skip the system permission sheet during UI-test screenshot runs.
        guard !ProcessInfo.processInfo.arguments.contains("-uitest-no-health") else { return false }
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Writing

    /// Saves a strength-training workout with its duration and active energy.
    /// Returns the created workout's UUID for de-duplication, or `nil` on failure.
    @discardableResult
    func saveStrengthWorkout(
        start: Date,
        end: Date,
        activeEnergyKcal: Double
    ) async -> UUID? {
        guard isAvailable else { return nil }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())

        do {
            try await builder.beginCollection(at: start)

            if activeEnergyKcal > 0,
               let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: activeEnergyKcal)
                let sample = HKCumulativeQuantitySample(
                    type: energyType,
                    quantity: quantity,
                    start: start,
                    end: end
                )
                try await builder.addSamples([sample])
            }

            try await builder.endCollection(at: end)
            let workout = try await builder.finishWorkout()
            return workout?.uuid
        } catch {
            return nil
        }
    }

    // MARK: - Reading

    func latestBodyMass() async -> Double? {
        await latestQuantity(.bodyMass, unit: .gramUnit(with: .kilo))
    }

    /// Body-fat as a fraction in `0...1`.
    func latestBodyFat() async -> Double? {
        await latestQuantity(.bodyFatPercentage, unit: .percent())
    }

    func latestHeartRate() async -> Double? {
        await latestQuantity(.heartRate, unit: HKUnit.count().unitDivided(by: .minute()))
    }

    /// Step count summed over today (calendar day, local timezone).
    func latestSteps() async -> Int? {
        guard isAvailable,
              let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                let count = stats?.sumQuantity()?.doubleValue(for: .count())
                continuation.resume(returning: count.map { Int($0) })
            }
            store.execute(query)
        }
    }

    /// Total time classified as "asleep" during the most-recent sleep window,
    /// expressed in hours. Looks back up to 24 hours for the most-recent night.
    func lastNightSleepHours() async -> Double? {
        guard isAvailable,
              let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }

        let lookback = Date().addingTimeInterval(-24 * 60 * 60)
        let predicate = HKQuery.predicateForSamples(withStart: lookback, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                // Sum durations across all "asleep" stages (core/deep/REM/
                // unspecified). `.asleep` was deprecated in iOS 16.
                let asleepValues = Set(HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue))
                let totalSeconds = samples
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                let hours = totalSeconds > 0 ? totalSeconds / 3_600 : nil
                continuation.resume(returning: hours)
            }
            store.execute(query)
        }
    }

    /// Most-recent VO₂ max sample in ml/(kg·min).
    func latestVO2Max() async -> Double? {
        // Unit: ml/(kg·min)
        let unit = HKUnit.literUnit(with: .milli)
            .unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))
        return await latestQuantity(.vo2Max, unit: unit)
    }

    private func latestQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async -> Double? {
        guard isAvailable, let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return nil
        }
        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}
