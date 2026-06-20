import SwiftUI
import WatchKit

/// Primary set-logging screen. Shown for a specific exercise (by index in
/// `store.exercises`). Provides:
///   - Weight + reps via Digital Crown + ±2.5/±1 step buttons.
///   - Pre-fill from the previous set.
///   - Big "Log Set" button with haptic feedback.
///   - Simple rest timer that starts automatically after each set.
///   - Logged-sets summary for the current exercise.
///   - Finish-workout flow with confirmation.
struct WatchSetLoggingView: View {
    @Environment(WatchDataStore.self) private var store

    let exerciseIndex: Int

    // Crown focus tag
    private enum Field: Hashable { case weight, reps }

    @State private var weight: Double = 20.0
    @State private var reps: Int = 10
    @FocusState private var focusedField: Field?

    // Rest timer lives in the store so the Action Button intent shares it.

    // Finish confirmation
    @State private var showFinishConfirm = false

    // MARK: - Derived

    private var exercise: WorkoutExerciseDTO? {
        store.exercises.indices.contains(exerciseIndex) ? store.exercises[exerciseIndex] : nil
    }

    private var previousSet: WorkoutSetDTO? { exercise?.sets.last }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.md) {

                // Machine name header
                if let ex = exercise {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: DS.Muscle.symbol(for: ex.machineName))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DS.Palette.accent)
                        Text(ex.machineName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer()
                        // Heart rate badge
                        if let hr = store.hkSession.currentHeartRate {
                            HStack(spacing: 2) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(DS.Palette.heart)
                                Text("\(Int(hr))")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(DS.Palette.heart)
                            }
                            .accessibilityLabel("Heart rate \(Int(hr)) bpm")
                        }
                    }
                    .padding(.horizontal, DS.Spacing.xs)
                }

                // Rest timer (shown after a set is logged)
                if store.isResting {
                    restTimerRow
                }

                // Weight entry
                weightRow

                // Reps entry
                repsRow

                // Summary label
                Text(String(format: "%.1f kg × %d", weight, reps))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                // Log Set button
                Button(action: logSet) {
                    Label("Log Set", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(DS.Palette.success, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Log set: \(String(format: "%.1f", weight)) kg, \(reps) reps")

                // Logged sets for this exercise
                if let ex = exercise, !ex.sets.isEmpty {
                    loggedSetsList(ex)
                }

                // Workout controls: elapsed + finish
                workoutFooter

            }
            .padding(DS.Spacing.md)
        }
        .navigationTitle("Log Set")
        .navigationBarBackButtonHidden(false)
        .onAppear(perform: prefill)
        .onAppear { focusedField = .weight }
        .confirmationDialog(
            "Finish Workout?",
            isPresented: $showFinishConfirm,
            titleVisibility: .visible
        ) {
            Button("Finish & Sync", role: .destructive) { store.finish() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Workout will be sent to iPhone.")
        }
    }

    // MARK: - Sub-views

    private var weightRow: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text("WEIGHT")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: DS.Spacing.sm) {
                stepButton(systemImage: "minus") { weight = max(0, weight - 2.5) }

                Text(String(format: "%.1f kg", weight))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .focusable()
                    .focused($focusedField, equals: .weight)
                    .digitalCrownRotation(
                        $weight,
                        from: 0,
                        through: 300,
                        by: 2.5,
                        sensitivity: .medium,
                        isContinuous: false,
                        isHapticFeedbackEnabled: true
                    )
                    .accessibilityLabel("Weight \(String(format: "%.1f", weight)) kilograms")
                    .onTapGesture { focusedField = .weight }

                stepButton(systemImage: "plus") { weight = min(300, weight + 2.5) }
            }
        }
        .padding(DS.Spacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    private var repsRow: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text("REPS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: DS.Spacing.sm) {
                stepButton(systemImage: "minus") { reps = max(1, reps - 1) }

                Text("\(reps)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .focusable()
                    .focused($focusedField, equals: .reps)
                    .digitalCrownRotation(
                        Binding(
                            get: { Double(reps) },
                            set: { reps = max(1, min(100, Int($0.rounded()))) }
                        ),
                        from: 1,
                        through: 100,
                        by: 1,
                        sensitivity: .medium,
                        isContinuous: false,
                        isHapticFeedbackEnabled: true
                    )
                    .accessibilityLabel("\(reps) repetitions")
                    .onTapGesture { focusedField = .reps }

                stepButton(systemImage: "plus") { reps = min(100, reps + 1) }
            }
        }
        .padding(DS.Spacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    private var restTimerRow: some View {
        HStack {
            Image(systemName: "timer")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.Palette.rest)
            Text("Rest  \(restFormatted)")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(DS.Palette.rest)
            Spacer()
            Button("Skip") {
                store.skipRest()
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
        }
        .padding(DS.Spacing.sm)
        .background(DS.Palette.rest.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rest timer \(restFormatted), double tap to skip")
    }

    private func loggedSetsList(_ ex: WorkoutExerciseDTO) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("SETS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)

            ForEach(Array(ex.sets.enumerated()), id: \.element.id) { idx, set in
                HStack {
                    Text("\(idx + 1)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, alignment: .leading)
                    Text(String(format: "%.1f kg × %d", set.weight, set.repetitions))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Set \(idx + 1): \(String(format: "%.1f", set.weight)) kg, \(set.repetitions) reps")
            }

            // Undo last set
            Button {
                store.removeLastSet(fromExerciseAt: exerciseIndex)
            } label: {
                Label("Undo last set", systemImage: "arrow.uturn.backward")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, DS.Spacing.xxs)
        }
        .padding(DS.Spacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    private var workoutFooter: some View {
        HStack {
            // Elapsed timer
            VStack(spacing: 2) {
                Text(elapsedFormatted)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.Palette.accent)
                Text("elapsed")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // Finish button
            Button(role: .destructive) {
                showFinishConfirm = true
            } label: {
                Label("Finish", systemImage: "flag.checkered")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(.red.opacity(0.18), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Finish workout")
        }
        .padding(.top, DS.Spacing.xs)
    }

    // MARK: - Helpers

    private func stepButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(Color.secondary.opacity(0.2), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func prefill() {
        // Mark this as the active exercise so the Action Button logs against it.
        store.currentExerciseIndex = exerciseIndex
        if let prev = previousSet {
            weight = prev.weight
            reps = prev.repetitions
        }
    }

    private func logSet() {
        store.currentExerciseIndex = exerciseIndex
        store.addSet(weight: weight, reps: reps, toExerciseAt: exerciseIndex)
        // Haptic feedback
        WKInterfaceDevice.current().play(.success)
        // Start the shared rest countdown (also driven by the Action Button)
        store.startRest()
        // Focus back to weight for next set
        focusedField = .weight
    }

    private var elapsedFormatted: String {
        let m = store.elapsedSeconds / 60
        let s = store.elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private var restFormatted: String {
        let m = store.restRemaining / 60
        let s = store.restRemaining % 60
        return String(format: "%d:%02d", m, s)
    }
}
