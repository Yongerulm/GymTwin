import SwiftUI

/// Detailed read-only view of a single past workout.
/// Accepts the `Workout` model directly; no extra view-model layer.
/// Restyled with MetricCard header row, premium SurfaceCard surfaces,
/// and a clear HealthKit sync indicator badge.
struct WorkoutDetailView: View {

    let workout: Workout

    private static let navTitleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                headerSection
                if !workout.notes.isEmpty {
                    notesSection
                }
                exercisesSection
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.xl)
        }
        .background(GymBackground().ignoresSafeArea())
        .navigationTitle(Self.navTitleFormatter.string(from: workout.date))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // HealthKit sync badge — shown above the stats when present
            if workout.healthKitWorkoutID != nil {
                healthKitBadge
            }

            // 2-column MetricCard grid: date, duration, volume, sets
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: DS.Spacing.md),
                    GridItem(.flexible(), spacing: DS.Spacing.md)
                ],
                spacing: DS.Spacing.md
            ) {
                MetricCard(
                    icon: "calendar",
                    title: "Date",
                    value: shortDate,
                    tint: DS.Palette.accent
                )
                MetricCard(
                    icon: "clock.fill",
                    title: "Duration",
                    value: durationString,
                    tint: DS.Palette.accentSecondary
                )
                MetricCard(
                    icon: "scalemass.fill",
                    title: "Total Volume",
                    value: volumeString,
                    unit: "kg",
                    tint: DS.Palette.success
                )
                MetricCard(
                    icon: "number",
                    title: "Total Sets",
                    value: "\(workout.totalSets)",
                    tint: DS.Palette.record
                )
            }
        }
    }

    private var healthKitBadge: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "heart.fill")
                .font(.subheadline)
                .foregroundStyle(DS.Palette.heart)
            Text("Synced to Apple Health")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.Palette.heart)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(DS.Palette.heart)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Palette.heart.opacity(0.10), in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .strokeBorder(DS.Palette.heart.opacity(0.22), lineWidth: 1)
        )
        .accessibilityLabel("Synced to Apple Health")
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            PremiumSectionHeader("Notes")
            SurfaceCard {
                Text(workout.notes)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Exercises

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            PremiumSectionHeader(
                "Exercises",
                subtitle: "\(workout.sortedExercises.count) machine\(workout.sortedExercises.count == 1 ? "" : "s")"
            )

            ForEach(workout.sortedExercises) { exercise in
                ExerciseDetailCard(exercise: exercise)
            }
        }
    }

    // MARK: - Formatted values

    private var shortDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: workout.date)
    }

    private var durationString: String {
        let total = Int(workout.duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    private var volumeString: String {
        let v = workout.totalVolume
        if v >= 1_000 {
            return String(format: "%.1f k", v / 1_000)
        }
        return String(format: "%.0f", v)
    }
}

// MARK: - ExerciseDetailCard

private struct ExerciseDetailCard: View {
    let exercise: WorkoutExercise

    var body: some View {
        SurfaceCard(padding: DS.Spacing.lg) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Machine name row + set count pill
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "dumbbell.fill")
                        .font(.subheadline)
                        .foregroundStyle(DS.Palette.accent)
                        .frame(width: 32, height: 32)
                        .background(DS.Palette.accent.opacity(0.14),
                                    in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                        .accessibilityHidden(true)

                    Text(exercise.machineName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    TagPill(
                        text: "\(exercise.sets.count) set\(exercise.sets.count == 1 ? "" : "s")",
                        tint: DS.Palette.accentSecondary
                    )
                }

                if !exercise.sortedSets.isEmpty {
                    Divider()
                        .overlay(DS.Palette.accent.opacity(0.10))

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        ForEach(Array(exercise.sortedSets.enumerated()), id: \.element.id) { index, set in
                            SetDetailRow(index: index + 1, set: set)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(exercise.machineName)
    }
}

// MARK: - SetDetailRow

private struct SetDetailRow: View {
    let index: Int
    let set: WorkoutSet

    var body: some View {
        HStack {
            Text("Set \(index)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)

            Text(setLabel)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()

            Spacer()

            Text(volumeLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityLabel("Set \(index): \(setLabel), \(volumeLabel) volume")
    }

    private var setLabel: String {
        String(format: "%.4g kg × %d", set.weight, set.repetitions)
    }

    private var volumeLabel: String {
        String(format: "%.0f kg", set.volume)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WorkoutDetailView(workout: {
            let w = Workout(date: Date(), duration: 3_060, notes: "Felt strong today.")
            return w
        }())
    }
    .preferredColorScheme(.dark)
}
