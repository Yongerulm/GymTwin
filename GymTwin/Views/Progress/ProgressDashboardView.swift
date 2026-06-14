import SwiftUI
import SwiftData
import Charts

/// Top-level Progress tab. Analytics, calm, not overcomplicated.
/// Owns its own NavigationStack; no-arg init for TabView wiring.
struct ProgressDashboardView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var model = ProgressViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if model.recentWorkouts.isEmpty && model.statistics.totalWorkouts == 0 {
                    emptyState
                } else {
                    scrollContent
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .background(GymBackground().ignoresSafeArea())
        }
        .task { model.bind(modelContext) }
        .onAppear { model.refresh() }
    }

    // MARK: - Main scroll content

    private var scrollContent: some View {
        ScrollView {
            LazyVStack(spacing: DS.Spacing.xl) {
                topMetricsSection
                recoverySection
                healthSection
                weeklyVolumeSection
                if !model.muscleBalance.isEmpty {
                    muscleBalanceSection
                }
                if !model.personalRecords.isEmpty {
                    personalRecordsSection
                }
                insightsSection
                if !model.recentWorkouts.isEmpty {
                    recentWorkoutsSection
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.xl)
        }
    }

    // MARK: - Top metrics row

    private var topMetricsSection: some View {
        VStack(spacing: DS.Spacing.md) {
            // 2-column grid: total workouts + volume
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: DS.Spacing.md),
                          GridItem(.flexible(), spacing: DS.Spacing.md)],
                spacing: DS.Spacing.md
            ) {
                MetricCard(
                    icon: "dumbbell.fill",
                    title: "Total Workouts",
                    value: "\(model.statistics.totalWorkouts)",
                    tint: DS.Palette.accent
                )
                MetricCard(
                    icon: "scalemass.fill",
                    title: "Total Volume",
                    value: model.formattedTotalVolume,
                    unit: "kg",
                    tint: DS.Palette.energy
                )
            }

            // Streak ring + this-week count side by side
            HStack(spacing: DS.Spacing.md) {
                ProgressRingCard(
                    title: "Weekly Goal",
                    progress: model.weeklyGoalProgress,
                    centerValue: "\(model.statistics.workoutsThisWeek)",
                    centerLabel: "of 5",
                    tint: DS.Palette.accent
                )
                ProgressRingCard(
                    title: "Streak",
                    progress: min(Double(model.statistics.currentStreakDays) / 7.0, 1.0),
                    centerValue: "\(model.statistics.currentStreakDays)",
                    centerLabel: model.statistics.currentStreakDays == 1 ? "day" : "days",
                    tint: DS.Palette.record
                )
            }
        }
    }

    // MARK: - Recovery ring

    private var recoverySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            PremiumSectionHeader("Recovery", subtitle: "Estimated readiness")

            ProgressRingCard(
                title: "Recovery Score",
                progress: Double(model.recoveryScore) / 100,
                centerValue: "\(model.recoveryScore)",
                centerLabel: "/ 100",
                tint: DS.Palette.rest
            )
            .accessibilityLabel("Recovery score: \(model.recoveryScore) out of 100")
        }
    }

    // MARK: - Health highlights

    private var healthSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            PremiumSectionHeader("Health", subtitle: "From Apple Health")

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: DS.Spacing.md),
                          GridItem(.flexible(), spacing: DS.Spacing.md)],
                spacing: DS.Spacing.md
            ) {
                MetricCard(
                    icon: "figure.walk",
                    title: "Steps",
                    value: model.steps.map { $0.formatted() } ?? "—",
                    unit: model.steps != nil ? "today" : nil,
                    tint: DS.Palette.heart
                )
                MetricCard(
                    icon: "moon.zzz.fill",
                    title: "Sleep",
                    value: model.sleepHours.map { String(format: "%.1f", $0) } ?? "—",
                    unit: model.sleepHours != nil ? "h" : nil,
                    tint: DS.Palette.energy
                )
                MetricCard(
                    icon: "heart.fill",
                    title: "Resting HR",
                    value: model.restingHR.map { "\($0)" } ?? "—",
                    unit: model.restingHR != nil ? "bpm" : nil,
                    tint: DS.Palette.rest
                )
                MetricCard(
                    icon: "lungs.fill",
                    title: "VO₂ Max",
                    value: model.vo2Max.map { String(format: "%.0f", $0) } ?? "—",
                    unit: model.vo2Max != nil ? "ml/kg·min" : nil,
                    tint: DS.Palette.accent
                )
            }
        }
    }

    // MARK: - Weekly volume bar chart

    private var weeklyVolumeSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            PremiumSectionHeader("Weekly Volume", subtitle: "Last 8 weeks")

            SurfaceCard {
                if model.weeklyVolume.allSatisfy({ $0.volume == 0 }) {
                    Text("No volume data yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                } else {
                    Chart(model.weeklyVolume, id: \.weekLabel) { item in
                        BarMark(
                            x: .value("Week", item.weekLabel),
                            y: .value("Volume (kg)", item.volume)
                        )
                        .foregroundStyle(DS.Palette.accentGradient)
                        .cornerRadius(6)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic) { _ in
                            AxisValueLabel()
                                .font(.caption2)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                            AxisGridLine(stroke: StrokeStyle(dash: [3, 3]))
                                .foregroundStyle(Color.white.opacity(0.06))
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(ProgressViewModel.formatVolume(v))
                                        .font(.caption2)
                                        .foregroundStyle(Color.secondary)
                                }
                            }
                        }
                    }
                    .frame(height: 160)
                    .accessibilityLabel("Weekly volume bar chart, last 8 weeks")
                }
            }
        }
    }

    // MARK: - Muscle balance

    private var muscleBalanceSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            PremiumSectionHeader("Muscle Balance", subtitle: "Volume by group")

            SurfaceCard {
                VStack(spacing: DS.Spacing.md) {
                    ForEach(model.muscleBalance.prefix(6), id: \.area) { item in
                        MuscleBalanceRow(
                            area: item.area,
                            volume: item.volume,
                            maxVolume: model.maxMuscleVolume
                        )
                    }
                }
            }
        }
    }

    // MARK: - Personal records

    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            PremiumSectionHeader("Personal Records", subtitle: "Best set per machine")

            SurfaceCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(model.personalRecords.prefix(6).enumerated()), id: \.offset) { index, item in
                        PRProgressRow(machineName: item.machineName, bestSet: item.bestSet)
                        if index < min(model.personalRecords.count, 6) - 1 {
                            Divider()
                                .padding(.leading, DS.Spacing.lg)
                                .overlay(DS.Palette.accent.opacity(0.08))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Insights (placeholder cards)

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            PremiumSectionHeader("Insights")

            CoachInsightCard(
                icon: "sparkles",
                title: "Keep It Up",
                message: "You have logged \(model.statistics.totalWorkouts) workout\(model.statistics.totalWorkouts == 1 ? "" : "s") so far. Stay consistent for the best results.",
                tint: DS.Palette.accent
            )

            if model.statistics.currentStreakDays == 0 {
                FatigueWarningCard(
                    message: "You haven't trained in a few days. Even a short session helps maintain your streak and momentum."
                )
            }
        }
    }

    // MARK: - Recent workouts

    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            PremiumSectionHeader("Recent Sessions", subtitle: "Last 20 workouts")

            SurfaceCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(model.recentWorkouts.enumerated()), id: \.element.id) { index, workout in
                        NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                            ProgressWorkoutRow(workout: workout)
                        }
                        .buttonStyle(.plain)
                        if index < model.recentWorkouts.count - 1 {
                            Divider()
                                .padding(.leading, DS.Spacing.lg)
                                .overlay(DS.Palette.accent.opacity(0.08))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        EmptyStateView(
            icon: "chart.line.uptrend.xyaxis",
            title: "No Data Yet",
            message: "Log your first workout to see analytics, personal records, and progress charts here."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Palette.background)
    }
}

// MARK: - MuscleBalanceRow

private struct MuscleBalanceRow: View {
    let area: String
    let volume: Double
    let maxVolume: Double

    private var progress: Double {
        guard maxVolume > 0 else { return 0 }
        return min(volume / maxVolume, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: DS.Muscle.symbol(for: area))
                        .font(.caption2)
                        .foregroundStyle(DS.Muscle.color(for: area))
                    Text(area)
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
                Text(ProgressViewModel.formatVolume(volume) + " kg")
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: DS.Radius.pill, style: .continuous)
                        .fill(DS.Muscle.color(for: area).opacity(0.12))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: DS.Radius.pill, style: .continuous)
                        .fill(DS.Muscle.color(for: area))
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(DS.Motion.spring, value: progress)
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(area): \(ProgressViewModel.formatVolume(volume)) kg")
    }
}

// MARK: - PRProgressRow

private struct PRProgressRow: View {
    let machineName: String
    let bestSet: WorkoutSet

    private var formattedBest: String {
        let w = bestSet.weight.formatted(.number.precision(.fractionLength(0...1)))
        return "\(w) kg × \(bestSet.repetitions)"
    }

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "trophy.fill")
                .font(.subheadline)
                .foregroundStyle(DS.Palette.record)
                .frame(width: 34, height: 34)
                .background(DS.Palette.record.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(machineName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(formattedBest)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            TagPill(text: "PR", tint: DS.Palette.record)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Personal record on \(machineName): \(formattedBest)")
    }
}

// MARK: - ProgressWorkoutRow

private struct ProgressWorkoutRow: View {
    let workout: Workout

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Date badge
            VStack(spacing: 2) {
                Text(dayString)
                    .font(.caption2.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Text(dateNumber)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(DS.Palette.accent)
            }
            .frame(width: 36)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(workout.date, style: .date)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: DS.Spacing.xs) {
                    Label("\(workout.totalSets) sets", systemImage: "repeat")
                    Text("·").foregroundStyle(.tertiary)
                    Label(formattedVolume + " kg", systemImage: "scalemass")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(workout.date.formatted(date: .long, time: .omitted)), \(workout.totalSets) sets, \(formattedVolume) kg")
    }

    private static let dayFormatter: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEE"; return f }()
    private static let numFormatter: DateFormatter = { let f = DateFormatter(); f.dateFormat = "d"; return f }()

    private var dayString: String { Self.dayFormatter.string(from: workout.date) }
    private var dateNumber: String { Self.numFormatter.string(from: workout.date) }
    private var formattedVolume: String { ProgressViewModel.formatVolume(workout.totalVolume) }
}

// MARK: - Preview

#Preview {
    ProgressDashboardView()
        .preferredColorScheme(.dark)
}
