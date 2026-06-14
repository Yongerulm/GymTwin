import SwiftUI

// MARK: - HealthSnapshotCard

/// 2×2 grid of health metric tiles pulled from HealthKit.
/// Shows "—" for any nil metric so the card always renders.
struct HealthSnapshotCard: View {
    let heartRate: Int?
    let bodyWeightKg: Double?
    let activeEnergyKcal: Int?
    let lastWorkoutMinutes: Int?

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(DS.Palette.heart)
                        .font(.caption.weight(.semibold))
                    Text("Health")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: DS.Spacing.md
                ) {
                    HealthMetricTile(
                        icon: "heart.fill",
                        value: heartRate.map { "\($0)" } ?? "—",
                        unit: heartRate != nil ? "bpm" : nil,
                        label: "Heart Rate",
                        tint: DS.Palette.heart
                    )
                    HealthMetricTile(
                        icon: "scalemass.fill",
                        value: bodyWeightKg.map { String(format: "%.1f", $0) } ?? "—",
                        unit: bodyWeightKg != nil ? "kg" : nil,
                        label: "Body Weight",
                        tint: DS.Palette.accent
                    )
                    HealthMetricTile(
                        icon: "bolt.fill",
                        value: activeEnergyKcal.map { "\($0)" } ?? "—",
                        unit: activeEnergyKcal != nil ? "kcal" : nil,
                        label: "Active Energy",
                        tint: DS.Palette.energy
                    )
                    HealthMetricTile(
                        icon: "timer",
                        value: lastWorkoutMinutes.map { "\($0)" } ?? "—",
                        unit: lastWorkoutMinutes != nil ? "min" : nil,
                        label: "Last Workout",
                        tint: DS.Palette.rest
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// Internal tile — not public, used only inside HealthSnapshotCard.
private struct HealthMetricTile: View {
    let icon: String
    let value: String
    let unit: String?
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if let unit {
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)\(unit.map { " \($0)" } ?? "")")
    }
}

// MARK: - SuggestedSetCard

/// "Suggested next set" coach card with big weight × reps display and
/// optional CTA button.
struct SuggestedSetCard: View {
    let machineName: String
    let weightText: String
    let repsText: String
    var note: String?
    var action: (() -> Void)?

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Header
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "wand.and.stars")
                        .foregroundStyle(DS.Palette.accentSecondary)
                        .font(.caption.weight(.semibold))
                    Text("Suggested Next Set")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(machineName)
                    .font(.headline)

                // Big weight × reps
                HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.sm) {
                    Text(weightText)
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(DS.Palette.accentGradient)
                    Text("×")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(repsText)
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(DS.Palette.accentGradient)
                }
                .accessibilityLabel("\(weightText) times \(repsText)")

                if let note {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let action {
                    Button("Use This Set", action: action)
                        .buttonStyle(GradientButtonStyle())
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - CoachInsightCard

/// Calm AI-insight card for training observations.
struct CoachInsightCard: View {
    var icon: String = "sparkles"
    let title: String
    let message: String
    var tint: Color = DS.Palette.accent

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(tint.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

// MARK: - RecommendationCard

/// AI recommendation surface with optional action button.
struct RecommendationCard: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundStyle(DS.Palette.accentGradient)
                    .frame(width: 36, height: 36)
                    .background(DS.Palette.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(GradientButtonStyle())
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(DS.Palette.accent.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 14, x: 0, y: 7)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - FatigueWarningCard

/// Calm amber fatigue notice shown when recovery indicators are low.
struct FatigueWarningCard: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: "moon.zzz.fill")
                .font(.headline)
                .foregroundStyle(DS.Palette.warning)
                .frame(width: 36, height: 36)
                .background(DS.Palette.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("Recovery Notice")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.Palette.warning)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Palette.warning.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(DS.Palette.warning.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recovery notice: \(message)")
    }
}

// MARK: - SuggestedNextSetView

/// Compact inline "57.5 kg · 10 reps · 3 sets" line used inside workout flow.
struct SuggestedNextSetView: View {
    let weightText: String
    let repsText: String
    var setsText: String?

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "wand.and.stars")
                .font(.caption2)
                .foregroundStyle(DS.Palette.accentSecondary)

            Group {
                Text(weightText)
                    .fontWeight(.semibold)
                separator
                Text("\(repsText) reps")
                    .fontWeight(.semibold)
                if let setsText {
                    separator
                    Text("\(setsText) sets")
                        .fontWeight(.semibold)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Suggested: \(weightText), \(repsText) reps\(setsText.map { ", \($0) sets" } ?? "")")
    }

    private var separator: some View {
        Text("·")
            .foregroundStyle(.secondary)
    }
}

// MARK: - Previews

#Preview("HealthSnapshotCard") {
    VStack(spacing: DS.Spacing.md) {
        HealthSnapshotCard(heartRate: 68, bodyWeightKg: 82.4, activeEnergyKcal: 340, lastWorkoutMinutes: 47)
        HealthSnapshotCard(heartRate: nil, bodyWeightKg: nil, activeEnergyKcal: nil, lastWorkoutMinutes: nil)
    }
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("SuggestedSetCard") {
    SuggestedSetCard(
        machineName: "Chest Press",
        weightText: "57.5 kg",
        repsText: "10",
        note: "Based on your last 3 sessions",
        action: {}
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("CoachInsightCard") {
    CoachInsightCard(
        title: "Volume Plateau Detected",
        message: "Your chest volume has been flat for 3 weeks. Consider adding a drop set to your final exercise."
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("RecommendationCard") {
    RecommendationCard(
        title: "Increase Chest Press",
        message: "You've hit 10 reps at 57.5 kg for 3 sessions. Time to progress to 60 kg.",
        actionTitle: "Update Weight",
        action: {}
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("FatigueWarningCard") {
    FatigueWarningCard(message: "Your training load has been high this week. Consider a lighter session today.")
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("SuggestedNextSetView") {
    VStack(spacing: DS.Spacing.md) {
        SuggestedNextSetView(weightText: "57.5 kg", repsText: "10", setsText: "3")
        SuggestedNextSetView(weightText: "80 kg", repsText: "8")
    }
    .padding()
    .preferredColorScheme(.dark)
}
