import Foundation
import WatchConnectivity

/// Thin, observable wrapper around `WCSession` shared by both platforms.
///
/// Only `Codable` value-type DTOs cross the wire (encoded to JSON `Data`),
/// never `@Model` objects. Delivery uses `transferUserInfo` (queued, survives
/// the peer being offline) plus `updateApplicationContext` for latest-state
/// catalog snapshots.
@MainActor
@Observable
final class WatchConnectivityService: NSObject {
    static let shared = WatchConnectivityService()

    /// Whether the counterpart app is currently reachable (live messaging).
    var isReachable = false
    /// Activation state for diagnostics / UI.
    var isActivated = false

    /// Assigned by the hosting app to ingest an incoming machine catalog
    /// (delivered on the watch).
    var onReceiveCatalog: ((GymCatalogDTO) -> Void)?
    /// Assigned by the hosting app to ingest a completed workout
    /// (delivered on the phone).
    var onReceiveWorkout: ((WorkoutDTO) -> Void)?

    private enum Key {
        static let catalog = "catalog"
        static let workout = "workout"
    }

    private override init() { super.init() }

    /// Activates the session. Safe to call once at app launch.
    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: Sending

    /// iPhone → Watch: push the machine catalog.
    func sendCatalog(_ catalog: GymCatalogDTO) {
        guard let data = try? JSONEncoder().encode(catalog) else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        session.transferUserInfo([Key.catalog: data])
        try? session.updateApplicationContext([Key.catalog: data])
    }

    /// Watch → iPhone: deliver a completed workout (queued, guaranteed).
    func sendWorkout(_ workout: WorkoutDTO) {
        guard let data = try? JSONEncoder().encode(workout) else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        session.transferUserInfo([Key.workout: data])
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let activated = activationState == .activated
        let reachable = session.isReachable
        Task { @MainActor in
            self.isActivated = activated
            self.isReachable = reachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        dispatch(payload: userInfo)
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        dispatch(payload: applicationContext)
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.isReachable = reachable }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif

    /// Decodes off the delegate queue so only `Sendable` DTOs hop to the main
    /// actor (never the non-`Sendable` `[String: Any]` dictionary).
    private nonisolated func dispatch(payload: [String: Any]) {
        let catalog = (payload[Key.catalog] as? Data)
            .flatMap { try? JSONDecoder().decode(GymCatalogDTO.self, from: $0) }
        let workout = (payload[Key.workout] as? Data)
            .flatMap { try? JSONDecoder().decode(WorkoutDTO.self, from: $0) }
        guard catalog != nil || workout != nil else { return }
        Task { @MainActor in
            if let catalog { self.onReceiveCatalog?(catalog) }
            if let workout { self.onReceiveWorkout?(workout) }
        }
    }
}
