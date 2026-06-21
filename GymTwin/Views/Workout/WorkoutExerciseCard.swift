import SwiftUI

// MARK: - ExerciseSessionCard

struct ExerciseSessionCard: View {
    let exercise: DraftExercise
    let exerciseIndex: Int
    /// Highlighted as the current exercise to work on (first not yet complete).
    var isActive: Bool = false
    let lastSession: WorkoutExercise?
    /// Logs a set at the predefined target (plan exercises only).
    var onCompleteSet: (() -> Void)? = nil
    /// Logs a set inline (weight, reps, type) without opening the modal sheet.
    var onLogSet: ((Double, Int, WorkoutSetType) -> Void)? = nil
    /// One-line coaching nudge for the active exercise (e.g. "Add 2.5 kg").
    var coachHint: String? = nil
    let onAddSet: () -> Void
    let onRepeatSet: () -> Void
    let onRemoveSet: (UUID) -> Void
    let onRemoveExercise: () -> Void
    /// Focus mode: only the expanded exercise shows its full controls.
    var isExpanded: Bool = true
    var onToggle: (() -> Void)? = nil

    /// 0…1 completion against the plan target (for the collapsed progress bar).
    private var planProgress: Double {
        guard let t = exercise.targetSets, t > 0 else { return exercise.sets.isEmpty ? 0 : 1 }
        return min(Double(exercise.sets.count) / Double(t), 1)
    }

    // Inline quick-add editor state.
    @State private var showInline = false
    @State private var inlineWeight: Double = 0
    @State private var inlineReps: Int = 0
    @State private var inlineType: WorkoutSetType = .working

    private func fmtWeight(_ w: Double) -> String {
        w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w)
    }

    private func targetStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 17, weight: .heavy)).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    /// Suggested next set: last weight + last reps from this session,
    /// falling back to the previous session's top set.
    private var suggestedWeight: Double? {
        exercise.sets.last?.weight
            ?? lastSession?.sortedSets.first?.weight
    }

    private var suggestedReps: Int? {
        exercise.sets.last?.reps
            ?? lastSession?.sortedSets.first?.repetitions
    }

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedNames.machineName(exercise.machineName))
                            .font(.headline.weight(.bold))
                        if let tSets = exercise.targetSets {
                            Text("\(exercise.sets.count)/\(tSets) sets")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(exercise.isPlanComplete ? DS.Palette.success : .secondary)
                        } else if !exercise.sets.isEmpty {
                            Text("\(exercise.sets.count) set\(exercise.sets.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if exercise.isPlanComplete {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(DS.Palette.success)
                    }
                    if onToggle != nil {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 26, height: 36)
                    }
                    if isExpanded {
                        Button(role: .destructive, action: onRemoveExercise) {
                            Image(systemName: "trash")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 36, height: 36)
                        }
                        .accessibilityLabel("Remove \(exercise.machineName) from session")
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { onToggle?() }

                // Collapsed: a thin progress bar is the only extra detail.
                if !isExpanded, exercise.targetSets != nil {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule().fill(exercise.isPlanComplete ? DS.Palette.success : DS.Palette.accent)
                                .frame(width: geo.size.width * planProgress)
                        }
                    }
                    .frame(height: 5)
                }

                if isExpanded {
                // In-set coaching nudge (active exercise only).
                if let coachHint {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "sparkles").font(.caption).foregroundStyle(DS.Palette.accent)
                        Text(coachHint).font(.caption.weight(.semibold)).foregroundStyle(DS.Palette.accent)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Palette.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    .accessibilityLabel("Coach: \(coachHint)")
                }

                // Predefined plan target + one-tap Complete Set.
                if let tReps = exercise.targetReps, let tWeight = exercise.targetWeight, let tSets = exercise.targetSets {
                    HStack(spacing: DS.Spacing.xl) {
                        targetStat("Set", "\(min(exercise.sets.count + (exercise.isPlanComplete ? 0 : 1), tSets))/\(tSets)")
                        targetStat("Target", "\(tReps) reps")
                        targetStat("Weight", "\(fmtWeight(tWeight)) kg")
                    }
                    if let onCompleteSet, !exercise.isPlanComplete {
                        Button(action: onCompleteSet) {
                            Label("Complete Set", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(GradientButtonStyle())
                        .accessibilityLabel("Complete a set on \(exercise.machineName) at target")
                    }
                }

                // Suggested next set chip (compact inline)
                if let w = suggestedWeight, let r = suggestedReps {
                    let weightStr = w.truncatingRemainder(dividingBy: 1) == 0
                        ? String(format: "%.0f kg", w)
                        : String(format: "%.1f kg", w)
                    SuggestedNextSetView(
                        weightText: weightStr,
                        repsText: "\(r)",
                        setsText: nil
                    )
                }

                // Logged sets
                if !exercise.sets.isEmpty {
                    Divider().opacity(0.3)
                    VStack(spacing: DS.Spacing.xs) {
                        ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { idx, set in
                            LoggedSetRow(
                                index: idx + 1,
                                set: set,
                                onRemove: { onRemoveSet(set.id) }
                            )
                        }
                    }
                }

                // Previous session reference (faint)
                if let prev = lastSession, !prev.sortedSets.isEmpty {
                    Divider().opacity(0.2)
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("Last session")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        ForEach(Array(prev.sortedSets.prefix(4).enumerated()), id: \.element.id) { idx, s in
                            Text("Set \(idx + 1)  \(formatSet(weight: s.weight, reps: s.repetitions))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                // Inline quick-add editor, or Add Set / Repeat buttons.
                if showInline, onLogSet != nil {
                    inlineEditor
                } else {
                    HStack(spacing: DS.Spacing.sm) {
                        Button {
                            if onLogSet != nil {
                                seedInline()
                                withAnimation(DS.Motion.snappy) { showInline = true }
                            } else {
                                onAddSet()
                            }
                        } label: {
                            Label("Add Set", systemImage: "plus.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DS.Palette.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DS.Spacing.sm)
                        }
                        .buttonStyle(.plain)
                        .background(
                            DS.Palette.accent.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                        )
                        .accessibilityLabel("Add a set to \(exercise.machineName)")

                        // One-tap copy of the previous set (same weight + reps).
                        if !exercise.sets.isEmpty {
                            Button(action: onRepeatSet) {
                                Label("Repeat", systemImage: "square.on.square")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(DS.Palette.success)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, DS.Spacing.sm)
                            }
                            .buttonStyle(.plain)
                            .background(
                                DS.Palette.success.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                            )
                            .accessibilityLabel("Repeat last set on \(exercise.machineName)")
                        }
                    }
                }
                } // if isExpanded
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(DS.Palette.accent.opacity(isActive ? 0.55 : 0), lineWidth: 1.5)
        )
        .shadow(color: DS.Palette.accent.opacity(isActive ? 0.18 : 0), radius: 12, x: 0, y: 5)
    }

    // MARK: - Inline quick-add editor

    private var inlineEditor: some View {
        VStack(spacing: DS.Spacing.sm) {
            // Set type quick-pick (warm-up, working, drop set, superset, AMRAP…).
            Menu {
                ForEach(WorkoutSetType.allCases, id: \.self) { type in
                    Button {
                        inlineType = type
                    } label: {
                        Label(type.label, systemImage: inlineType == type ? "checkmark" : "")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(inlineType.label).font(.caption.weight(.bold))
                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                }
                .foregroundStyle(inlineType == .working ? Color.secondary : DS.Palette.accentSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityLabel("Set type: \(inlineType.label)")

            HStack(spacing: DS.Spacing.md) {
                inlineStepper(label: "kg", value: fmtWeight(inlineWeight),
                              dec: { inlineWeight = max(0, inlineWeight - 2.5) },
                              inc: { inlineWeight += 2.5 })
                inlineStepper(label: "reps", value: "\(inlineReps)",
                              dec: { inlineReps = max(1, inlineReps - 1) },
                              inc: { inlineReps += 1 })
            }
            HStack(spacing: DS.Spacing.sm) {
                Button {
                    onLogSet?(inlineWeight, inlineReps, inlineType)
                    withAnimation(DS.Motion.snappy) { showInline = false }
                } label: {
                    Label("Log", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                }
                .buttonStyle(GradientButtonStyle())
                .accessibilityLabel("Log \(fmtWeight(inlineWeight)) kg for \(inlineReps) reps")

                Button { onAddSet(); showInline = false } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 40)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Advanced set options")

                Button { withAnimation(DS.Motion.snappy) { showInline = false } } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 40)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel")
            }
        }
    }

    private func inlineStepper(label: String, value: String, dec: @escaping () -> Void, inc: @escaping () -> Void) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            inlineStepButton("minus", dec)
            VStack(spacing: 0) {
                Text(value).font(.headline.weight(.bold)).monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            inlineStepButton("plus", inc)
        }
        .padding(.vertical, 4)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
    }

    private func inlineStepButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.bold))
                .foregroundStyle(DS.Palette.accent)
                .frame(width: 40, height: 40)
                .background(DS.Palette.accent.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func seedInline() {
        inlineWeight = exercise.sets.last?.weight ?? exercise.targetWeight ?? lastSession?.sortedSets.first?.weight ?? 20
        inlineReps = exercise.sets.last?.reps ?? exercise.targetReps ?? lastSession?.sortedSets.first?.repetitions ?? 10
    }

    private func formatSet(weight: Double, reps: Int) -> String {
        let w = weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f kg", weight)
            : String(format: "%.1f kg", weight)
        return "\(w) × \(reps)"
    }
}

// MARK: - LoggedSetRow

struct LoggedSetRow: View {
    let index: Int
    let set: DraftSet
    let onRemove: () -> Void

    private var formattedSet: String {
        let w = set.weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f kg", set.weight)
            : String(format: "%.1f kg", set.weight)
        return "\(w) × \(set.reps)"
    }

    var body: some View {
        HStack {
            Text("Set \(index)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)
            Text(formattedSet)
                .font(.body.weight(.semibold).monospacedDigit())
            if let tag = set.type.tag {
                Text(tag)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(DS.Palette.accentSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DS.Palette.accentSecondary.opacity(0.15), in: Capsule())
            }
            Spacer()
            Button(role: .destructive, action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove set \(index)")
        }
        .padding(.vertical, 2)
    }
}
