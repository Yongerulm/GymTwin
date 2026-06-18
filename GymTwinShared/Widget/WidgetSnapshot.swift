import Foundation

/// A small, Codable snapshot of the data the home-screen / lock-screen widgets
/// render. The app writes it to the shared App Group on every refresh; the
/// widget extension reads it from its timeline provider. Using a flat snapshot
/// (rather than opening the SwiftData store from the extension) keeps the
/// widget lean and decoupled from the model schema.
public struct WidgetSnapshot: Codable, Sendable, Equatable {
    public var updated: Date
    public var workoutsThisWeek: Int
    public var weeklyGoal: Int
    public var currentStreakDays: Int
    /// HRV-led daily readiness 0–100.
    public var readiness: Int
    /// Short banded title for readiness (e.g. "Ready", "Peak").
    public var readinessTitle: String
    /// The muscle group most ready to train, for a one-glance suggestion.
    public var topReadyMuscle: String?
    /// Whether a workout is currently in progress.
    public var isWorkoutActive: Bool

    public init(
        updated: Date,
        workoutsThisWeek: Int,
        weeklyGoal: Int,
        currentStreakDays: Int,
        readiness: Int,
        readinessTitle: String,
        topReadyMuscle: String?,
        isWorkoutActive: Bool
    ) {
        self.updated = updated
        self.workoutsThisWeek = workoutsThisWeek
        self.weeklyGoal = weeklyGoal
        self.currentStreakDays = currentStreakDays
        self.readiness = readiness
        self.readinessTitle = readinessTitle
        self.topReadyMuscle = topReadyMuscle
        self.isWorkoutActive = isWorkoutActive
    }

    /// Neutral placeholder used before the app has written anything, and for
    /// widget previews / gallery snapshots.
    public static let placeholder = WidgetSnapshot(
        updated: .distantPast,
        workoutsThisWeek: 3,
        weeklyGoal: 5,
        currentStreakDays: 4,
        readiness: 72,
        readinessTitle: "Ready",
        topReadyMuscle: "Chest",
        isWorkoutActive: false
    )

    public var weeklyGoalProgress: Double {
        guard weeklyGoal > 0 else { return 0 }
        return min(Double(workoutsThisWeek) / Double(weeklyGoal), 1)
    }
}

/// Reads and writes the widget snapshot in the shared App Group `UserDefaults`.
public enum WidgetSnapshotStore {
    private static let key = "widget.snapshot.v1"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.identifier)
    }

    public static func load() -> WidgetSnapshot {
        guard
            let data = defaults?.data(forKey: key),
            let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return .placeholder }
        return snapshot
    }

    public static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: key)
    }

    /// Update only the `isWorkoutActive` flag without recomputing the rest —
    /// used when a session starts/ends so the widget reflects it immediately.
    public static func setWorkoutActive(_ active: Bool) {
        var snapshot = load()
        snapshot.isWorkoutActive = active
        save(snapshot)
    }
}

/// Cross-process hand-off flags for App Intents (e.g. "Start Workout" from
/// Siri / a widget tap) that the app consumes on next activation.
public enum WidgetIntentBridge {
    private static let startKey = "pending.start.workout"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.identifier)
    }

    public static func requestStartWorkout() {
        defaults?.set(true, forKey: startKey)
    }

    /// Returns true once if a start was requested, then clears the flag.
    public static func consumeStartWorkout() -> Bool {
        guard defaults?.bool(forKey: startKey) == true else { return false }
        defaults?.removeObject(forKey: startKey)
        return true
    }
}
