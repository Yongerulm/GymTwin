import Foundation
import WidgetKit

/// Bridges app state into the shared widget snapshot and refreshes the
/// home-screen / lock-screen timelines. Keeps the widget decoupled from the
/// SwiftData store — the app pushes a flat snapshot whenever data changes.
enum WidgetSyncService {

    /// Write the latest training + readiness summary and reload all widgets.
    @MainActor
    static func update(
        statistics: TrainingStatistics,
        weeklyGoal: Int = 5,
        readiness: Int,
        readinessTitle: String,
        topReadyMuscle: String?
    ) {
        let snapshot = WidgetSnapshot(
            updated: Date(),
            workoutsThisWeek: statistics.workoutsThisWeek,
            weeklyGoal: weeklyGoal,
            currentStreakDays: statistics.currentStreakDays,
            readiness: readiness,
            readinessTitle: readinessTitle,
            topReadyMuscle: topReadyMuscle,
            isWorkoutActive: WidgetSnapshotStore.load().isWorkoutActive
        )
        WidgetSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Flip the in-progress flag and reload, so the widget reflects a session
    /// starting or ending without waiting for a full refresh.
    static func setWorkoutActive(_ active: Bool) {
        WidgetSnapshotStore.setWorkoutActive(active)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
