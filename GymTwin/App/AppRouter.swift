import SwiftUI

/// Top-level tabs of the iOS app. Four tabs, training-first IA:
/// Today (home), Train (hub: plans + gym twin), Progress, Profile.
/// Scanning is folded into Start (Today) and the live session, not a tab.
enum AppTab: Hashable {
    case dashboard
    case workouts
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

    /// When true the flow skips the program picker and starts in free /
    /// scan-first mode (used by the dedicated Scan tab).
    var workoutScanMode = false
    /// When set, the flow loads this plan directly and skips the picker.
    var workoutPlanID: String?
    /// Machine code from a background NFC tag deep link (gymtwin://machine/<code>).
    var workoutScanCode: String?

    /// Start a session from a tapped NFC tag (no system scan sheet): loads the
    /// machine for the given code into a fresh session.
    func startWorkout(scanCode: String) {
        workoutMachineID = nil
        workoutScanMode = false
        workoutPlanID = nil
        workoutScanCode = scanCode
        isWorkoutActive = true
    }

    /// Start a workout from anywhere. With no machine it opens the program
    /// picker first; pre-selecting a machine skips straight into the session.
    func startWorkout(machineID: UUID? = nil) {
        workoutMachineID = machineID
        workoutScanMode = false
        workoutPlanID = nil
        isWorkoutActive = true
    }

    /// Start a workout directly on a chosen plan (skips the program picker).
    func startWorkout(planID: String) {
        workoutMachineID = nil
        workoutScanMode = false
        workoutPlanID = planID
        isWorkoutActive = true
    }

    /// Start a scan-first session (free training, no program picker).
    func startScan() {
        workoutMachineID = nil
        workoutScanMode = true
        workoutPlanID = nil
        isWorkoutActive = true
    }

    func endWorkout() {
        isWorkoutActive = false
        workoutMachineID = nil
        workoutScanMode = false
        workoutPlanID = nil
        workoutScanCode = nil
    }

    /// Jump to the Workouts hub (which hosts the gym digital twin).
    func openGym() { selectedTab = .workouts }
    /// Jump to the Analytics tab.
    func openProgress() { selectedTab = .analytics }
}
