import SwiftUI
import SwiftData

/// Modal sheet for entering a single set: weight (kg) + reps.
/// Uses large `WorkoutControlStepper` for one-handed operation.
/// Pre-fills from the last logged set of the exercise.
///
/// When `machineID` is supplied and a `ModelContext` is available the view
/// queries `CoachService` for an AI-suggested weight/reps and surfaces it as a
/// subtle hint above the steppers. The hint can be dismissed; it never forces
/// the user's values.
struct WorkoutSetEntryView: View {
    let exerciseName: String
    let lastWeight: Double
    let lastReps: Int
    /// Optional — when present, drives the AI suggestion hint.
    var machineID: UUID?
    let onAdd: (Double, Int, WorkoutSetType) -> Void
    let onCancel: () -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var weight: Double
    @State private var reps: Double
    @State private var setType: WorkoutSetType = .working
    @State private var didLog = false
    @State private var aiSuggestion: SetRecommendation?
    /// The machine's predefined settings (Seat Height, etc.) for reference.
    @State private var settings: [(title: String, value: String)] = []

    init(
        exerciseName: String,
        lastWeight: Double,
        lastReps: Int,
        machineID: UUID? = nil,
        onAdd: @escaping (Double, Int, WorkoutSetType) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.exerciseName = exerciseName
        self.lastWeight = lastWeight
        self.lastReps = lastReps
        self.machineID = machineID
        self.onAdd = onAdd
        self.onCancel = onCancel
        _weight = State(initialValue: lastWeight)
        _reps = State(initialValue: Double(lastReps))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, DS.Spacing.md)

            // Title
            VStack(spacing: DS.Spacing.xxs) {
                Text(exerciseName)
                    .font(.headline.weight(.bold))
                    .padding(.top, DS.Spacing.lg)
                Text("Log Set")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, DS.Spacing.md)

            // Predefined machine settings (Seat Height, etc.) — reference.
            if !settings.isEmpty {
                settingsRow
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.md)
            }

            // AI suggestion hint
            if let suggestion = aiSuggestion {
                aiHint(suggestion)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.md)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Steppers
            VStack(spacing: DS.Spacing.lg) {
                WorkoutControlStepper(
                    label: "Weight",
                    value: $weight,
                    step: 2.5,
                    range: 0...500,
                    unit: "kg"
                )

                WorkoutControlStepper(
                    label: "Reps",
                    value: $reps,
                    step: 1,
                    range: 1...100,
                    unit: "reps",
                    format: { "\(Int($0))" }
                )
            }
            .padding(.horizontal, DS.Spacing.lg)

            // Set type selector
            Menu {
                ForEach(WorkoutSetType.allCases, id: \.self) { t in
                    Button(t.label) { setType = t }
                }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "tag.fill").font(.caption)
                    Text(setType.label)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.caption)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.Palette.accent)
                .padding(.vertical, DS.Spacing.sm)
                .padding(.horizontal, DS.Spacing.md)
                .background(DS.Palette.surfaceElevated, in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
            }
            .padding(.top, DS.Spacing.md)
            .padding(.horizontal, DS.Spacing.lg)
            .accessibilityLabel("Set type: \(setType.label)")

            Spacer(minLength: DS.Spacing.xl)

            // Actions
            VStack(spacing: DS.Spacing.sm) {
                Button {
                    didLog = true
                    onAdd(weight, Int(reps), setType)
                } label: {
                    Label("Log Set", systemImage: "plus.circle.fill")
                }
                .buttonStyle(GradientButtonStyle())
                .sensoryFeedback(.success, trigger: didLog)
                .disabled(weight <= 0 || reps < 1)
                .padding(.horizontal, DS.Spacing.lg)

                Button("Cancel", action: onCancel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, DS.Spacing.lg)
            }
        }
        .background(GymBackground().ignoresSafeArea())
        .animation(DS.Motion.spring, value: aiSuggestion != nil)
        .task { loadAISuggestion() }
    }

    // MARK: - AI hint row

    private func aiHint(_ suggestion: SetRecommendation) -> some View {
        Button {
            // Tapping the hint pre-fills the steppers with the suggested values.
            weight = suggestion.weight
            reps = Double(suggestion.reps)
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "wand.and.stars")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DS.Palette.accentSecondary)

                let weightText = formatWeight(suggestion.weight)
                Text("AI suggests \(weightText) · \(suggestion.reps) reps")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.Palette.accentSecondary)

                Text("— tap to use")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Palette.accentSecondary.opacity(0.09), in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .strokeBorder(DS.Palette.accentSecondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("AI suggests \(formatWeight(suggestion.weight)) times \(suggestion.reps) reps. Tap to apply.")
    }

    // MARK: - Load AI suggestion

    private func loadAISuggestion() {
        guard let machineID else { return }
        let coach = CoachService(context: modelContext)
        let rec = coach.nextSet(forMachineID: machineID, goal: .muscleGain)
        // Only show the hint when the coach has a meaningful non-zero suggestion
        // and it differs from the pre-filled last-set values (to avoid noise).
        if rec.weight > 0 {
            aiSuggestion = rec
        }
        // Load the machine's predefined settings for reference.
        if let machine = (try? modelContext.fetch(
            FetchDescriptor<Machine>(predicate: #Predicate { $0.id == machineID })
        ))?.first {
            settings = machine.sortedSettings.map { (title: $0.title, value: $0.value) }
        }
    }

    // MARK: - Predefined settings row

    private var settingsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(settings, id: \.title) { setting in
                    MachineSettingChip(title: setting.title, value: setting.value)
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f kg", w)
            : String(format: "%.1f kg", w)
    }
}

// MARK: - Preview

#Preview("WorkoutSetEntryView") {
    WorkoutSetEntryView(
        exerciseName: "Chest Press",
        lastWeight: 57.5,
        lastReps: 10,
        onAdd: { w, r, _ in print("Logged \(w) kg × \(r)") },
        onCancel: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("WorkoutSetEntryView — with AI hint") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Machine.self, Workout.self, Gym.self, GymArea.self,
        configurations: config
    )
    return WorkoutSetEntryView(
        exerciseName: "Chest Press",
        lastWeight: 55.0,
        lastReps: 10,
        machineID: UUID(),
        onAdd: { w, r, _ in print("Logged \(w) kg × \(r)") },
        onCancel: {}
    )
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
