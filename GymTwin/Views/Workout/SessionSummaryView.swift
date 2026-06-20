import SwiftUI

/// Identifiable carrier so the summary can drive a `.sheet(item:)`.
struct SessionSummaryData: Identifiable {
    let id = UUID()
    let durationMinutes: Int
    let exerciseCount: Int
    let totalSets: Int
    let totalVolume: Double
    let volumeDeltaPercent: Double?
    let newPRs: [String]
    let streakDays: Int
}

/// The post-session "habit moment": shown right after a workout is finished.
/// Celebrates what just happened — duration, volume, sets, any new PRs, and how
/// today compares to last time — then nudges the streak. Pure presentation:
/// callers pass precomputed values so it stays decoupled from services.
struct SessionSummaryView: View {
    let durationMinutes: Int
    let exerciseCount: Int
    let totalSets: Int
    let totalVolume: Double
    /// Volume change vs the previous comparable session (nil if unknown).
    let volumeDeltaPercent: Double?
    /// Human-readable PR lines, e.g. "Chest Press · 60 kg".
    let newPRs: [String]
    let streakDays: Int
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                header
                statsGrid
                if !newPRs.isEmpty { prSection }
                if streakDays > 0 { streakRow }
                Button(action: onDone) {
                    Text("Done")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GradientButtonStyle())
                .padding(.top, DS.Spacing.sm)
            }
            .padding(DS.Spacing.lg)
            .padding(.top, DS.Spacing.xl)
        }
        .background(GymBackground().ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(DS.Palette.accentGradient)
                .accessibilityHidden(true)
            Text("Workout complete")
                .font(.title.weight(.heavy))
                .multilineTextAlignment(.center)
            Text(summaryLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var summaryLine: String {
        var parts = ["\(durationMinutes) min", "\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")", "\(totalSets) sets"]
        if let delta = volumeDeltaPercent, abs(delta) >= 1 {
            parts.append(delta >= 0 ? "+\(Int(delta))% volume" : "\(Int(delta))% volume")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Stats

    private var statsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: DS.Spacing.md),
                      GridItem(.flexible(), spacing: DS.Spacing.md)],
            spacing: DS.Spacing.md
        ) {
            statCard("Duration", "\(durationMinutes)", unit: "min", tint: DS.Palette.accent, icon: "clock.fill")
            statCard("Volume", volumeText, unit: "kg", tint: DS.Palette.energy, icon: "scalemass.fill")
            statCard("Sets", "\(totalSets)", unit: nil, tint: DS.Palette.success, icon: "checkmark.circle.fill")
            statCard("Exercises", "\(exerciseCount)", unit: nil, tint: DS.Palette.record, icon: "dumbbell.fill")
        }
    }

    private var volumeText: String {
        totalVolume >= 1_000
            ? (totalVolume / 1_000).formatted(.number.precision(.fractionLength(1))) + "k"
            : totalVolume.formatted(.number.precision(.fractionLength(0)))
    }

    private func statCard(_ title: String, _ value: String, unit: String?, tint: Color, icon: String) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Image(systemName: icon).font(.title3).foregroundStyle(tint)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value).font(.title2.weight(.heavy)).monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
                    if let unit { Text(unit).font(.caption).foregroundStyle(.secondary) }
                }
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - PRs

    private var prSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            PremiumSectionHeader("New Personal Records", subtitle: "Today you beat your best")
            ForEach(newPRs, id: \.self) { pr in
                SurfaceCard {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "trophy.fill").foregroundStyle(DS.Palette.record)
                        Text(pr).font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Streak

    private var streakRow: some View {
        SurfaceCard {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "flame.fill").font(.title3).foregroundStyle(DS.Palette.energy)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(streakDays)-day streak")
                        .font(.headline.weight(.bold))
                    Text("Keep the momentum — train again tomorrow.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(streakDays) day streak. Keep the momentum.")
    }
}
