import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Starts, updates, and ends the Live Activity for an in-progress workout.
/// Elapsed time is rendered live by the widget from `startedAt`, so state
/// updates are only pushed when the logged sets / current exercise change.
///
/// All entry points are invoked from the (MainActor) workout view model, so
/// access to the stored activity is effectively serialised; ActivityKit's own
/// calls are safe from any isolation. No-ops gracefully where ActivityKit is
/// unavailable (e.g. the Simulator without Live Activities).
enum WorkoutLiveActivityController {

    #if canImport(ActivityKit)
    // Serialised in practice (only touched from the MainActor view model).
    nonisolated(unsafe) private static var activity: Activity<WorkoutActivityAttributes>?

    static func start(gymName: String, startedAt: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, activity == nil else { return }
        let attributes = WorkoutActivityAttributes(startedAt: startedAt, gymName: gymName)
        let state = WorkoutActivityAttributes.ContentState(
            currentExercise: "Warming up",
            setsLogged: 0,
            planProgress: nil
        )
        activity = try? Activity.request(
            attributes: attributes,
            content: .init(state: state, staleDate: nil)
        )
    }

    static func update(currentExercise: String, setsLogged: Int, planProgress: String?) async {
        guard let activity else { return }
        let state = WorkoutActivityAttributes.ContentState(
            currentExercise: currentExercise,
            setsLogged: setsLogged,
            planProgress: planProgress
        )
        await activity.update(.init(state: state, staleDate: nil))
    }

    static func end() async {
        guard let activity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        Self.activity = nil
    }
    #else
    static func start(gymName: String, startedAt: Date) {}
    static func update(currentExercise: String, setsLogged: Int, planProgress: String?) async {}
    static func end() async {}
    #endif
}
