import SwiftUI

/// Top-level tabs of the iOS app. Four tabs, training-first IA:
/// Today (home), Gym (digital twin), Progress (analytics), Settings.
enum AppTab: Hashable {
    case today
    case gym
    case progress
    case settings
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
    var selectedTab: AppTab = .today

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

    func openGym() { selectedTab = .gym }
    func openProgress() { selectedTab = .progress }
}
