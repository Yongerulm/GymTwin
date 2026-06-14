import Foundation
import HealthKit

/// Wraps `HKWorkoutSession` + `HKLiveWorkoutBuilder` to collect heart rate and
/// active energy during a strength-training session on the watch.
///
/// Guards `HKHealthStore.isHealthDataAvailable()` so the class compiles and
/// runs safely on the watch simulator where HealthKit is unavailable.
@Observable
@MainActor
final class WatchWorkoutSession: NSObject {

    // MARK: - Published state

    /// Most-recently received heart rate in bpm, or `nil` if unavailable.
    private(set) var currentHeartRate: Double?
    /// Accumulated active energy in kcal.
    private(set) var activeEnergyKcal: Double = 0
    /// Whether the HK session is currently running.
    private(set) var isRunning = false

    // MARK: - Private

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    // MARK: - Authorization

    /// Requests write access to active energy + workout type and read access
    /// to heart rate. Returns `true` if the request completed without error.
    @discardableResult
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        var share = Set<HKSampleType>()
        var read = Set<HKObjectType>()
        share.insert(HKObjectType.workoutType())
        if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            share.insert(energy)
        }
        if let hr = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            read.insert(hr)
        }
        do {
            try await store.requestAuthorization(toShare: share, read: read)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Session control

    /// Starts the HK workout session. Silently no-ops if HealthKit is
    /// unavailable or if a session is already running.
    func start() async {
        guard HKHealthStore.isHealthDataAvailable(), !isRunning else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor

        do {
            let newSession = try HKWorkoutSession(healthStore: store, configuration: config)
            let newBuilder = newSession.associatedWorkoutBuilder()
            newBuilder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)

            newSession.delegate = self
            newBuilder.delegate = self

            session = newSession
            builder = newBuilder

            newSession.startActivity(with: .now)
            try await newBuilder.beginCollection(at: .now)
            isRunning = true
        } catch {
            // HealthKit not authorized or session already running — silently skip.
        }
    }

    /// Ends the session and finalises the builder. Returns without throwing.
    func end() async {
        guard let session, let builder, isRunning else { return }
        session.end()
        do {
            try await builder.endCollection(at: .now)
            _ = try await builder.finishWorkout()
        } catch {
            // Finalisation failure is non-fatal.
        }
        self.session = nil
        self.builder = nil
        isRunning = false
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchWorkoutSession: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {}

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        Task { @MainActor in self.isRunning = false }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchWorkoutSession: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        var hr: Double?
        var energy: Double?

        if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate),
           collectedTypes.contains(hrType),
           let stat = workoutBuilder.statistics(for: hrType) {
            hr = stat.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        }

        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
           collectedTypes.contains(energyType),
           let stat = workoutBuilder.statistics(for: energyType) {
            energy = stat.sumQuantity()?.doubleValue(for: .kilocalorie())
        }

        Task { @MainActor in
            if let hr { self.currentHeartRate = hr }
            if let energy { self.activeEnergyKcal = energy }
        }
    }
}
