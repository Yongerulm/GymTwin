import Foundation
import SwiftData
import WatchConnectivity

/// Backs `SettingsView`. Reads and writes the single `Gym`, manages
/// HealthKit authorisation state, surfaces the latest body metrics, and
/// exposes Apple Watch pairing/reachability status.
@Observable
@MainActor
final class SettingsViewModel {

    // MARK: - Published state

    private(set) var healthKitAuthorized: Bool = false
    private(set) var isHealthKitAvailable: Bool = false

    /// Latest body mass in kilograms, nil if never recorded or access denied.
    private(set) var bodyMass: Double?
    /// Latest body-fat percentage (0…100 range), nil if unavailable.
    private(set) var bodyFatPercent: Double?
    /// Latest resting/snapshot heart rate in bpm, nil if unavailable.
    private(set) var heartRate: Double?

    /// Editable gym name — bound two-way to a `TextField` in the view.
    var gymName: String = ""
    /// Editable gym location — bound two-way to a `TextField` in the view.
    var gymLocation: String = ""

    /// Non-nil while the HealthKit authorisation request is in flight.
    private(set) var isRequestingAccess: Bool = false

    /// Whether an Apple Watch is paired with this iPhone.
    /// Uses `WCSession.default.isPaired` when Watch Connectivity is supported;
    /// returns `false` on devices where it is not (e.g. iPad).
    var watchConnected: Bool {
        guard WCSession.isSupported() else { return false }
        return WCSession.default.isPaired
    }

    /// Whether the companion Watch app is currently reachable for live messaging.
    var watchReachable: Bool {
        guard WCSession.isSupported() else { return false }
        return WCSession.default.isReachable
    }

    // MARK: - Private

    private var context: ModelContext?
    private var gym: Gym?

    // MARK: - Binding

    func bind(_ context: ModelContext) {
        self.context = context
        isHealthKitAvailable = HealthKitService.shared.isAvailable
        loadGym()
        Task { await loadHealthMetrics() }
    }

    // MARK: - Gym

    private func loadGym() {
        guard let context else { return }
        let descriptor = FetchDescriptor<Gym>(sortBy: [SortDescriptor(\.createdDate)])
        let gyms = (try? context.fetch(descriptor)) ?? []
        gym = gyms.first
        gymName = gym?.name ?? ""
        gymLocation = gym?.location ?? ""
    }

    /// Persists any edits the user has made to name / location.
    func saveGym() {
        guard let context, let gym else { return }
        gym.name = gymName
        gym.location = gymLocation
        try? context.save()
    }

    // MARK: - HealthKit

    func requestHealthAccess() async {
        guard isHealthKitAvailable, !isRequestingAccess else { return }
        isRequestingAccess = true
        defer { isRequestingAccess = false }
        healthKitAuthorized = await HealthKitService.shared.requestAuthorization()
        await loadHealthMetrics()
    }

    func loadHealthMetrics() async {
        guard isHealthKitAvailable else { return }
        async let mass = HealthKitService.shared.latestBodyMass()
        async let fat = HealthKitService.shared.latestBodyFat()
        async let hr = HealthKitService.shared.latestHeartRate()
        let (m, f, h) = await (mass, fat, hr)
        bodyMass = m
        // HealthKit returns fraction (0…1); convert to percentage for display.
        bodyFatPercent = f.map { $0 * 100 }
        heartRate = h
        // If any metric came back, assume authorization was granted at some point.
        if m != nil || f != nil || h != nil {
            healthKitAuthorized = true
        }
    }
}
