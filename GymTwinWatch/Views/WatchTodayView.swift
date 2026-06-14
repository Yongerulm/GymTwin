import SwiftUI

/// Watch home screen. Three large tap targets drive the three core flows:
/// resume / start workout, browse machines, and machine-level set logging.
///
/// When a workout is active the top card shows the live timer and heart rate
/// and navigates directly to WatchSetLoggingView for the most-recent exercise.
struct WatchTodayView: View {
    @Environment(WatchDataStore.self) private var store

    @State private var showMachines = false
    @State private var showWorkout = false

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.sm) {
                // Primary card: active workout resumption or start-workout CTA
                workoutCard

                // Machine browser
                NavigationLink(destination: WatchMachineView()) {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(DS.Palette.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Machines")
                                .font(.system(size: 15, weight: .semibold))
                            Text("\(store.catalog.count) in catalog")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(DS.Spacing.md)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.top, DS.Spacing.xs)
        }
        .navigationTitle(store.gymName.isEmpty ? "Gym Twin" : store.gymName)
    }

    // MARK: - Workout card

    @ViewBuilder
    private var workoutCard: some View {
        if store.isWorkoutActive {
            activeWorkoutCard
        } else {
            startWorkoutButton
        }
    }

    private var startWorkoutButton: some View {
        NavigationLink(destination: WatchMachineView(selectionMode: true)) {
            HStack(spacing: DS.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(DS.Palette.accent.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(DS.Palette.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start Workout")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Pick a machine to begin")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(DS.Spacing.md)
            .background(DS.Palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .strokeBorder(DS.Palette.accent.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// Card shown while a workout is in progress. Tapping navigates to logging.
    private var activeWorkoutCard: some View {
        NavigationLink(destination: activeWorkoutDestination) {
            VStack(spacing: DS.Spacing.xs) {
                HStack {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.Palette.accent)
                    Text("Workout Active")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.Palette.accent)
                    Spacer()
                    // Heart rate badge
                    if let hr = store.hkSession.currentHeartRate {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(DS.Palette.heart)
                            Text("\(Int(hr))")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(DS.Palette.heart)
                        }
                        .accessibilityLabel("Heart rate \(Int(hr)) bpm")
                    }
                }

                HStack {
                    // Elapsed timer
                    Text(elapsedFormatted)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                    Spacer()
                    // Set / exercise summary
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(store.exercises.count)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(store.exercises.count == 1 ? "exercise" : "exercises")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }

                // Resume hint
                Text("Tap to log a set →")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(DS.Spacing.md)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .strokeBorder(DS.Palette.accent.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// Navigate to the last exercise's set-logging screen, or the machine picker
    /// if the active workout has no exercises yet.
    @ViewBuilder
    private var activeWorkoutDestination: some View {
        if let lastIdx = store.exercises.indices.last {
            WatchSetLoggingView(exerciseIndex: lastIdx)
        } else {
            WatchMachineView(selectionMode: true)
        }
    }

    // MARK: - Helpers

    private var elapsedFormatted: String {
        let m = store.elapsedSeconds / 60
        let s = store.elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
