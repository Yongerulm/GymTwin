import SwiftUI

/// User profile tab.
/// Persists display name, training goal, bodyweight, and height via
/// `@AppStorage` — no SwiftData schema changes required. Shows a computed
/// summary card derived from the stored values.
struct ProfileView: View {

    // MARK: - Persisted state (@AppStorage only)

    @AppStorage("profile.displayName") private var displayName: String = ""
    @AppStorage("profile.goal") private var goalRaw: String = TrainingGoal.muscleGain.rawValue
    @AppStorage("profile.bodyweightKg") private var bodyweightKg: Double = 0
    @AppStorage("profile.heightCm") private var heightCm: Double = 0

    // MARK: - Derived

    private var goal: TrainingGoal {
        TrainingGoal(rawValue: goalRaw) ?? .muscleGain
    }

    private var bmi: Double? {
        guard heightCm > 0, bodyweightKg > 0 else { return nil }
        let heightM = heightCm / 100
        return bodyweightKg / (heightM * heightM)
    }

    private var bmiCategory: String {
        guard let bmi else { return "" }
        switch bmi {
        case ..<18.5: return "Underweight"
        case 18.5..<25: return "Healthy range"
        case 25..<30: return "Overweight"
        default: return "Obese"
        }
    }

    // Bodyweight and height as `@State` strings for TextField binding so the
    // user can type freely; we parse and persist on commit.
    @State private var bodyweightText: String = ""
    @State private var heightText: String = ""
    @State private var editingBodyweight = false
    @State private var editingHeight = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    avatarHeader
                    summaryCard
                    personalSection
                    goalsSection
                    bodySection
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xl)
            }
            .background(DS.Palette.background)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            // Sync string mirrors from stored doubles on every appear.
            bodyweightText = bodyweightKg > 0 ? String(format: "%.1f", bodyweightKg) : ""
            heightText = heightCm > 0 ? String(format: "%.0f", heightCm) : ""
        }
    }

    // MARK: - Avatar header

    private var avatarHeader: some View {
        VStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DS.Palette.accentGradient)
                    .frame(width: 88, height: 88)
                    .shadow(color: DS.Palette.accent.opacity(0.4), radius: 18, x: 0, y: 8)

                Text(initials)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            if !displayName.isEmpty {
                Text(displayName)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
            }

            TagPill(
                text: goal.rawValue,
                systemImage: goalIcon(for: goal),
                tint: goalTint(for: goal)
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(displayName.isEmpty ? "No name set" : displayName). Goal: \(goal.rawValue)")
    }

    private var initials: String {
        let words = displayName
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        switch words.count {
        case 0: return "GT"
        case 1: return String(words[0].prefix(2)).uppercased()
        default: return "\(words[0].prefix(1))\(words[1].prefix(1))".uppercased()
        }
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.Palette.accent)
                    Text("Your Focus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: DS.Spacing.xl) {
                    // Goal summary
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text("Goal")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(goal.rawValue)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(goalTint(for: goal))
                    }

                    Divider().frame(height: 30).opacity(0.2)

                    // Target reps
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text("Target reps")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text("\(goal.targetReps)")
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                    }

                    Divider().frame(height: 30).opacity(0.2)

                    // Sets per exercise
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text("Sets")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text("\(goal.setCount)")
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                    }

                    if let bmi {
                        Divider().frame(height: 30).opacity(0.2)

                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text("BMI")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f", bmi))
                                .font(.subheadline.weight(.bold))
                                .monospacedDigit()
                            Text(bmiCategory)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Goal: \(goal.rawValue). Target \(goal.targetReps) reps, \(goal.setCount) sets.")
    }

    // MARK: - Personal section

    private var personalSection: some View {
        VStack(spacing: DS.Spacing.md) {
            PremiumSectionHeader("Personal")

            SurfaceCard {
                VStack(spacing: 0) {
                    // Display name
                    profileRow(
                        icon: "person.fill",
                        iconTint: DS.Palette.accent,
                        label: "Name"
                    ) {
                        TextField("Your name", text: $displayName)
                            .multilineTextAlignment(.trailing)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .submitLabel(.done)
                            .accessibilityLabel("Display name")
                    }
                }
            }
        }
    }

    // MARK: - Goals section

    private var goalsSection: some View {
        VStack(spacing: DS.Spacing.md) {
            PremiumSectionHeader("Training Goal")

            SurfaceCard {
                VStack(spacing: DS.Spacing.lg) {
                    Picker("Training Goal", selection: Binding(
                        get: { goal },
                        set: { goalRaw = $0.rawValue }
                    )) {
                        ForEach(TrainingGoal.allCases, id: \.self) { g in
                            Text(g.rawValue).tag(g)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Select training goal")

                    // Goal detail
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: goalIcon(for: goal))
                            .font(.headline)
                            .foregroundStyle(goalTint(for: goal))
                            .frame(width: 36, height: 36)
                            .background(
                                goalTint(for: goal).opacity(0.14),
                                in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                            )

                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text(goal.rawValue)
                                .font(.subheadline.weight(.semibold))
                            Text(goalDescription(for: goal))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .animation(DS.Motion.spring, value: goal)
                }
            }
        }
    }

    // MARK: - Body section

    private var bodySection: some View {
        VStack(spacing: DS.Spacing.md) {
            PremiumSectionHeader("Body Stats")

            SurfaceCard {
                VStack(spacing: 0) {
                    // Body weight
                    profileRow(
                        icon: "scalemass.fill",
                        iconTint: DS.Palette.accentSecondary,
                        label: "Weight"
                    ) {
                        HStack(spacing: DS.Spacing.xxs) {
                            TextField("0.0", text: $bodyweightText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline)
                                .frame(maxWidth: 70)
                                .onSubmit { commitBodyweight() }
                                .onChange(of: bodyweightText) { _, _ in commitBodyweight() }
                                .accessibilityLabel("Body weight in kilograms")
                            Text("kg")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()
                        .padding(.leading, 52)
                        .opacity(0.15)

                    // Height
                    profileRow(
                        icon: "ruler.fill",
                        iconTint: DS.Palette.success,
                        label: "Height"
                    ) {
                        HStack(spacing: DS.Spacing.xxs) {
                            TextField("0", text: $heightText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline)
                                .frame(maxWidth: 70)
                                .onSubmit { commitHeight() }
                                .onChange(of: heightText) { _, _ in commitHeight() }
                                .accessibilityLabel("Height in centimetres")
                            Text("cm")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if bodyweightKg == 0 || heightCm == 0 {
                Text("Add your body stats to unlock BMI tracking in the summary above.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DS.Spacing.xs)
            }
        }
    }

    // MARK: - Row helper

    @ViewBuilder
    private func profileRow<Trailing: View>(
        icon: String,
        iconTint: Color,
        label: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .fill(iconTint.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(iconTint)
            }

            Text(label)
                .font(.subheadline)

            Spacer()

            trailing()
        }
        .padding(.vertical, DS.Spacing.sm)
    }

    // MARK: - Commit helpers

    private func commitBodyweight() {
        if let parsed = Double(bodyweightText.replacingOccurrences(of: ",", with: ".")), parsed > 0 {
            bodyweightKg = parsed
        }
    }

    private func commitHeight() {
        if let parsed = Double(heightText), parsed > 0 {
            heightCm = parsed
        }
    }

    // MARK: - Goal metadata

    private func goalIcon(for goal: TrainingGoal) -> String {
        switch goal {
        case .muscleGain: return "figure.strengthtraining.traditional"
        case .strength: return "dumbbell.fill"
        case .endurance: return "figure.run"
        case .fatLoss: return "flame.fill"
        }
    }

    private func goalTint(for goal: TrainingGoal) -> Color {
        switch goal {
        case .muscleGain: return DS.Palette.accent
        case .strength: return DS.Palette.record
        case .endurance: return DS.Palette.success
        case .fatLoss: return DS.Palette.energy
        }
    }

    private func goalDescription(for goal: TrainingGoal) -> String {
        switch goal {
        case .muscleGain:
            return "Moderate weight, \(goal.targetReps) reps, \(goal.setCount) sets — maximise time under tension."
        case .strength:
            return "Heavy loads, \(goal.targetReps) reps, \(goal.setCount) sets — progressive overload with long rest."
        case .endurance:
            return "Lighter weight, \(goal.targetReps) reps, \(goal.setCount) sets — keep rest short and heart rate up."
        case .fatLoss:
            return "Moderate weight, \(goal.targetReps) reps, \(goal.setCount) sets — circuit style for maximum caloric burn."
        }
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
        .preferredColorScheme(.dark)
}
