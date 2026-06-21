import Foundation

/// Per-muscle-group recovery estimate (0–100 %).
///
/// Each muscle group recovers over a window of hours that starts when it was
/// last trained. Larger muscles (legs, back) need longer than small ones
/// (arms, core), and a high-volume session extends the window. The percentage
/// rises linearly from 0 % (just trained) to 100 % (fully recovered); a muscle
/// that has not been trained recently is considered fresh (100 %).
///
/// The service is pure and deterministic — it takes plain training events and a
/// reference `now`, so it is trivial to unit-test without SwiftData or the clock.
struct MuscleRecoveryService {

    // MARK: - Muscle groups

    /// A trainable muscle group with its baseline full-recovery window.
    struct Group: Sendable {
        let key: String        // canonical, lowercase (e.g. "chest")
        let label: String      // display name (e.g. "Chest")
        let baseWindowHours: Double
    }

    /// The muscle groups tracked for recovery, largest/slowest first.
    /// Cardio is intentionally excluded — recovery here is muscular.
    static let groups: [Group] = [
        Group(key: "legs",      label: "Legs",      baseWindowHours: 72),
        Group(key: "back",      label: "Back",      baseWindowHours: 64),
        Group(key: "chest",     label: "Chest",     baseWindowHours: 48),
        Group(key: "shoulders", label: "Shoulders", baseWindowHours: 48),
        Group(key: "arms",      label: "Arms",      baseWindowHours: 36),
        Group(key: "core",      label: "Core",      baseWindowHours: 36),
    ]

    /// Reference single-session volume (kg) at which the recovery window is
    /// fully extended. Heavier sessions tax the muscle longer.
    private static let referenceVolume: Double = 2_000

    // MARK: - Public API

    /// Compute the recovery status for every tracked muscle group.
    ///
    /// - Parameters:
    ///   - events: One entry per muscle-group session (date + that session's volume).
    ///   - now: The reference time recovery is measured against.
    static func statuses(events: [MuscleTrainingEvent], now: Date) -> [MuscleRecoveryStatus] {
        // Keep only the most recent session per muscle group.
        var latest: [String: MuscleTrainingEvent] = [:]
        for event in events {
            if let existing = latest[event.muscle], existing.date >= event.date { continue }
            latest[event.muscle] = event
        }

        return groups.map { group in
            guard let event = latest[group.key] else {
                return MuscleRecoveryStatus(
                    muscle: group.key,
                    displayName: group.label,
                    recoveryPercent: 100,
                    lastTrained: nil,
                    hoursSinceTrained: nil
                )
            }

            let hours = max(0, now.timeIntervalSince(event.date) / 3_600)
            let window = recoveryWindowHours(forMuscle: group.key, lastVolume: event.volume)
            let percent = window > 0 ? min(100, Int((hours / window * 100).rounded())) : 100

            return MuscleRecoveryStatus(
                muscle: group.key,
                displayName: group.label,
                recoveryPercent: percent,
                lastTrained: event.date,
                hoursSinceTrained: hours
            )
        }
    }

    /// Full-recovery window in hours for a muscle, extended by session volume.
    /// Volume scales the base window by 0.85×–1.30×.
    static func recoveryWindowHours(forMuscle muscle: String, lastVolume: Double) -> Double {
        let base = groups.first { $0.key == muscle }?.baseWindowHours ?? 48
        let load = min(max(lastVolume, 0) / referenceVolume, 1.5)   // 0...1.5
        let factor = 0.85 + 0.3 * load                              // 0.85...1.30
        return base * factor
    }

    /// Map an arbitrary area/category string to a canonical muscle-group key,
    /// or `nil` when it is not a tracked muscle (e.g. cardio, unknown).
    static func canonicalMuscle(from area: String) -> String? {
        let a = area.lowercased()
        if a.contains("chest") || a.contains("pec") { return "chest" }
        if a.contains("back") || a.contains("lat") || a.contains("row") { return "back" }
        if a.contains("leg") || a.contains("quad") || a.contains("glute")
            || a.contains("hamstring") || a.contains("calf") { return "legs" }
        if a.contains("shoulder") || a.contains("delt") { return "shoulders" }
        if a.contains("arm") || a.contains("bicep") || a.contains("tricep") { return "arms" }
        if a.contains("core") || a.contains("ab") || a.contains("oblique") { return "core" }
        return nil
    }
}

// MARK: - Inputs / outputs

/// A single muscle-group training session, distilled from a workout.
struct MuscleTrainingEvent: Sendable {
    let muscle: String   // canonical group key
    let date: Date
    let volume: Double   // weight × reps summed for that muscle in the session
}

/// How recovered a muscle group is, banded for a clear recommendation.
struct MuscleRecoveryStatus: Identifiable, Sendable {
    var id: String { muscle }
    let muscle: String
    let displayName: String
    let recoveryPercent: Int      // 0...100
    let lastTrained: Date?
    let hoursSinceTrained: Double?

    var band: MuscleRecoveryBand {
        guard lastTrained != nil else { return .fresh }
        switch recoveryPercent {
        case ..<55: return .recovering
        case 55..<90: return .building
        default: return .ready
        }
    }
}

/// Recovery band with a short, calm coaching label.
enum MuscleRecoveryBand: Sendable {
    case recovering   // still under-recovered, train other groups
    case building     // partially recovered
    case ready        // recovered, good to train
    case fresh        // not trained recently

    var label: String {
        switch self {
        case .recovering: return String(localized: "Recovering")
        case .building:   return String(localized: "Building")
        case .ready:      return String(localized: "Ready")
        case .fresh:      return String(localized: "Fresh")
        }
    }
}
