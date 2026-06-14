import SwiftUI
import SwiftData

/// AI training-plan generator tab.
/// Lets the user pick a goal and weekly frequency, generates a split plan via
/// `PlanViewModel`, then renders each training day with its machine list and a
/// coach rationale card.
struct PlanGeneratorView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(GymSelection.self) private var gymSelection
    @State private var model = PlanViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    configSection
                    generateButton
                    if let plan = model.plan {
                        planContent(plan)
                    } else if !model.isGenerating {
                        emptyState
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xl)
                .animation(DS.Motion.spring, value: model.plan?.id)
            }
            .background(DS.Palette.background)
            .navigationTitle("Training Plan")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            // Default the plan to the gym the user is currently training in.
            if model.selectedGymID == nil { model.selectedGymID = gymSelection.activeGymID }
            model.bind(modelContext)
        }
    }

    // MARK: - Config section

    private var configSection: some View {
        SurfaceCard {
            VStack(spacing: DS.Spacing.lg) {
                // Gym picker
                if model.gyms.count > 1 || model.selectedGymID != nil {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "building.2.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(DS.Palette.accent)
                            Text("Gym")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Menu {
                            ForEach(model.gyms) { gym in
                                Button(gym.name) { model.selectedGymID = gym.id }
                            }
                        } label: {
                            HStack {
                                Text(model.gyms.first { $0.id == model.selectedGymID }?.name ?? "Select gym")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, DS.Spacing.sm)
                            .padding(.horizontal, DS.Spacing.md)
                            .background(DS.Palette.surfaceElevated, in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                        }
                        .accessibilityLabel("Select gym for this plan")
                    }

                    Divider().opacity(0.15)
                }

                // Goal picker
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "target")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DS.Palette.accent)
                        Text("Goal")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Picker("Training Goal", selection: $model.goal) {
                        ForEach(TrainingGoal.allCases, id: \.self) { goal in
                            Text(goal.rawValue).tag(goal)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Select your training goal")
                }

                Divider().opacity(0.15)

                // Days stepper
                HStack {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "calendar")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(DS.Palette.accentSecondary)
                            Text("Days per week")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Text("\(model.daysPerWeek) day\(model.daysPerWeek == 1 ? "" : "s")")
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }

                    Spacer()

                    Stepper(
                        "",
                        value: $model.daysPerWeek,
                        in: 1...6
                    )
                    .labelsHidden()
                    .accessibilityLabel("Training days per week, \(model.daysPerWeek)")
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: if model.daysPerWeek < 6 { model.daysPerWeek += 1 }
                        case .decrement: if model.daysPerWeek > 1 { model.daysPerWeek -= 1 }
                        @unknown default: break
                        }
                    }
                }
            }
        }
    }

    // MARK: - Generate button

    private var generateButton: some View {
        Button {
            Task { await model.generate() }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                if model.isGenerating {
                    ProgressView()
                        .scaleEffect(0.85)
                        .tint(.white)
                }
                Label(
                    model.isGenerating ? "Generating…" : "Generate Plan",
                    systemImage: model.isGenerating ? "" : "sparkles"
                )
            }
        }
        .buttonStyle(GradientButtonStyle())
        .disabled(model.isGenerating)
        .accessibilityLabel(model.isGenerating ? "Generating plan" : "Generate training plan")
    }

    // MARK: - Empty state

    private var emptyState: some View {
        EmptyStateView(
            icon: "calendar.badge.plus",
            title: "No Plan Yet",
            message: "Choose your goal and weekly frequency above, then tap Generate Plan to get a personalised training schedule."
        )
        .padding(.top, DS.Spacing.xxxl)
    }

    // MARK: - Plan content

    @ViewBuilder
    private func planContent(_ plan: TrainingPlan) -> some View {
        VStack(spacing: DS.Spacing.xl) {
            // Plan header
            planHeader(plan)

            // Coach rationale
            CoachInsightCard(
                icon: "sparkles",
                title: "Why this split?",
                message: model.splitRationale,
                tint: DS.Palette.accent
            )

            // Days
            VStack(spacing: DS.Spacing.md) {
                PremiumSectionHeader(
                    "Your Schedule",
                    subtitle: "\(plan.daysPerWeek) day\(plan.daysPerWeek == 1 ? "" : "s") · \(plan.split.rawValue)"
                )

                ForEach(plan.days) { day in
                    planDayCard(day)
                }
            }
        }
    }

    // MARK: - Plan header strip

    private func planHeader(_ plan: TrainingPlan) -> some View {
        SurfaceCard {
            HStack(spacing: DS.Spacing.xl) {
                // Goal chip
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Goal")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(plan.goal.rawValue)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(DS.Palette.accentGradient)
                }

                Divider()
                    .frame(height: 36)
                    .opacity(0.2)

                // Split chip
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Split")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(plan.split.rawValue)
                        .font(.subheadline.weight(.bold))
                }

                Divider()
                    .frame(height: 36)
                    .opacity(0.2)

                // Target reps chip
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Target reps")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("\(plan.goal.targetReps)")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                }

                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Plan: \(plan.goal.rawValue), \(plan.split.rawValue), \(plan.goal.targetReps) target reps")
    }

    // MARK: - Day card

    private func planDayCard(_ day: PlanDay) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Day header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(day.title)
                            .font(.headline)
                        Text(day.focus)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    TagPill(
                        text: "\(day.machineCodes.count) exercise\(day.machineCodes.count == 1 ? "" : "s")",
                        systemImage: "dumbbell.fill",
                        tint: DS.Palette.accentSecondary
                    )
                }

                if day.machineCodes.isEmpty {
                    Text("Rest or light cardio")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .italic()
                } else {
                    // Machine list
                    let names = model.machineList(for: day)
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        ForEach(names.indices, id: \.self) { idx in
                            HStack(spacing: DS.Spacing.sm) {
                                Circle()
                                    .fill(DS.Palette.accent.opacity(0.6))
                                    .frame(width: 6, height: 6)
                                Text(names[idx])
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Exercise \(idx + 1): \(names[idx])")
                        }
                    }
                    .padding(.top, DS.Spacing.xxs)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(day.title), \(day.focus)")
    }
}

// MARK: - Preview

#Preview {
    PlanGeneratorView()
        .modelContainer(for: [Workout.self, WorkoutExercise.self, WorkoutSet.self], inMemory: true)
        .preferredColorScheme(.dark)
}
