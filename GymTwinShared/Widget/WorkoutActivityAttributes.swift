#if canImport(ActivityKit)
import ActivityKit
import Foundation

/// Live Activity attributes for an in-progress workout. The static `gymName`
/// and `startedAt` are fixed for the session; `ContentState` carries the
/// values that change as the user logs sets. The elapsed time is rendered
/// live by the widget via `Text(timerInterval:)` from `startedAt`, so we do
/// not push a per-second state update.
public struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        /// Name of the exercise currently being worked.
        public var currentExercise: String
        /// Total sets logged so far in the session.
        public var setsLogged: Int
        /// Optional guided-plan position, e.g. "Exercise 2/5".
        public var planProgress: String?

        public init(currentExercise: String, setsLogged: Int, planProgress: String? = nil) {
            self.currentExercise = currentExercise
            self.setsLogged = setsLogged
            self.planProgress = planProgress
        }
    }

    /// Wall-clock start of the session, used for the live timer.
    public var startedAt: Date
    /// Gym / app label shown on the activity.
    public var gymName: String

    public init(startedAt: Date, gymName: String) {
        self.startedAt = startedAt
        self.gymName = gymName
    }
}
#endif
