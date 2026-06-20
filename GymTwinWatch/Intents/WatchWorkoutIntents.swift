import AppIntents

/// App Intents the user can bind to the **Apple Watch Ultra Action Button**
/// (Settings → Action Button → Shortcut) and to Siri. During a session a single
/// press logs the next set and starts the rest; a second intent skips the rest.

/// Log the next set on the current exercise and start the rest timer.
struct LogNextSetIntent: AppIntent {
    static var title: LocalizedStringResource { "Log Next Set" }
    static var description: IntentDescription {
        IntentDescription("Logs the next set on the current machine and starts your rest timer.")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        WatchDataStore.shared.logNextSet()
        return .result()
    }
}

/// End the current rest immediately and continue to the next set.
struct SkipRestIntent: AppIntent {
    static var title: LocalizedStringResource { "Skip Rest" }
    static var description: IntentDescription {
        IntentDescription("Ends the current rest and jumps straight to the next set.")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        WatchDataStore.shared.skipRest()
        return .result()
    }
}

/// Surfaces the intents to Siri / Shortcuts / the Action Button picker.
struct GymTwinWatchShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogNextSetIntent(),
            phrases: [
                "Log next set in \(.applicationName)",
                "Next set in \(.applicationName)",
            ],
            shortTitle: "Log Next Set",
            systemImageName: "checkmark.circle.fill"
        )
        AppShortcut(
            intent: SkipRestIntent(),
            phrases: [
                "Skip rest in \(.applicationName)",
            ],
            shortTitle: "Skip Rest",
            systemImageName: "forward.fill"
        )
    }
}
