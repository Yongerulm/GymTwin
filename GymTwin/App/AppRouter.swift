import SwiftUI

/// Top-level tabs of the iOS app. Five tabs, training-first IA:
/// Dashboard (home), Workouts (training hub), Scan (fast start),
/// Analytics (progress), Profile (settings).
enum AppTab: Hashable {
    case dashboard
    case workouts
    case scan
    case analytics
    case profile
}

/// Lightweight cross-feature navigation state. Features remain decoupled —
/// each owns its own `NavigationStack` — while this router enables the few
/// genuinely cross-tab intents (start a workout, jump to the gym, etc.).
///
/// A workout is a *modal flow* presented over any tab, not a tab itself, so
/// training is always one tap away and stays focused while it runs.
@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .dashboard

    /// Drives the full-screen workout flow. When `isWorkoutActive` is true the
    /// flow is presented; `workoutMachineID` optionally pre-seeds a machine.
    var isWorkoutActive = false
    var workoutMachineID: UUID?

    /// Start a workout from anywhere, optionally pre-selecting a machine.
    func startWorkout(machineID: UUID? = nil) {
        workoutMachineID = machineID
        isWorkoutActive = true
    }

    func endWorkout() {
        isWorkoutActive = false
        workoutMachineID = nil
    }

    /// Jump to the Workouts hub (which hosts the gym digital twin).
    func openGym() { selectedTab = .workouts }
    /// Jump to the Analytics tab.
    func openProgress() { selectedTab = .analytics }
}
