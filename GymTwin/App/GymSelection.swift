import SwiftUI
import SwiftData

/// Tracks which gym the user is currently training in. Persisted across
/// launches, injected into the environment, and read by the Gym tab, the scan
/// flow and the training-plan generator so each can scope itself to one gym.
@MainActor
@Observable
final class GymSelection {
    private static let key = "active.gym.id"

    var activeGymID: UUID? {
        didSet { persist() }
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.key) {
            activeGymID = UUID(uuidString: raw)
        }
    }

    private func persist() {
        if let id = activeGymID {
            UserDefaults.standard.set(id.uuidString, forKey: Self.key)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.key)
        }
    }

    /// Resolve the active gym from a list, defaulting to the first gym when the
    /// stored id is missing or stale.
    func activeGym(from gyms: [Gym]) -> Gym? {
        if let id = activeGymID, let match = gyms.first(where: { $0.id == id }) { return match }
        return gyms.first
    }
}
