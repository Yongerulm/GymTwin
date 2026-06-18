import AppIntents

/// Siri / Shortcuts / widget-tap entry point for starting a session.
/// Opens the app and signals a pending start via the shared App Group; the
/// app consumes the flag on activation and presents the workout flow.
struct StartWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource { "Start Workout" }
    static var description: IntentDescription { IntentDescription("Starts a new training session in FitPilot AI.") }
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        WidgetIntentBridge.requestStartWorkout()
        return .result()
    }
}

/// Exposes the app's intents to Siri and Spotlight with spoken phrases.
struct GymTwinShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWorkoutIntent(),
            phrases: [
                "Start a workout in \(.applicationName)",
                "Start training in \(.applicationName)",
                "Begin my \(.applicationName) session"
            ],
            shortTitle: "Start Workout",
            systemImageName: "figure.strengthtraining.traditional"
        )
    }
}
