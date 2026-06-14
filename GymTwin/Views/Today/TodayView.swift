import SwiftUI
import SwiftData

/// Today tab — the emotional and functional home of the app.
/// One NavigationStack with a scrollable composition of premium cards.
struct TodayView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    @State private var model = TodayViewModel()
    @State private var showingScanFlow = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: DS.Spacing.xl) {
                    heroSection
                    scanMachineButton
                    nextMachineSection
                    quickActionsSection
                    healthSection
                    recentMachinesSection
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xl)
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .background(GymBackground().ignoresSafeArea())
        }
        .task {
            model.bind(modelContext)
        }
        .onAppear {
            model.refresh()
        }
        .fullScreenCover(isPresented: $showingScanFlow) {
            ScanFlowView()
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroSection: some View {
        HeroWorkoutCard(
            title: heroTitle,
            subtitle: heroSubtitle,
            dateText: model.dateText,
            lastSummary: model.lastSummary.map { "Last time: \($0)" },
            startAction: { router.startWorkout() }
        )
    }

    private var heroTitle: String {
        if model.todaysWorkout != nil {
            return "Session Logged"
        }
        return model.greeting
    }

    private var heroSubtitle: String {
        if let workout = model.todaysWorkout {
            let sets = workout.totalSets
            let durationMin = Int(workout.duration / 60)
            return "\(sets) set\(sets == 1 ? "" : "s") · \(durationMin) min"
        }
        if model.statistics.currentStreakDays > 1 {
            return "\(model.statistics.currentStreakDays)-day streak · Keep it going"
        }
        return "Ready for today's workout"
    }

    // MARK: - Scan Machine button

    private var scanMachineButton: some View {
        Button {
            showingScanFlow = true
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DS.Palette.accentGradient)
                    .frame(width: 48, height: 48)
                    .background(DS.Palette.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan Machine")
                        .font(.headline.weight(.bold))
                    Text("QR · NFC · code — start in seconds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(DS.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .strokeBorder(DS.Palette.accent.opacity(0.18), lineWidth: 1.5)
            )
            .shadow(color: DS.Palette.accent.opacity(0.12), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Scan machine QR code or NFC tag to start training")
    }

    // MARK: - Next Machine + Coach Insight

    @ViewBuilder
    private var nextMachineSection: some View {
        if let machine = model.nextMachine {
            VStack(spacing: DS.Spacing.md) {
                PremiumSectionHeader(
                    "Up Next",
                    subtitle: "Based on your training history"
                )

                MachineCard(
                    name: machine.name,
                    category: machine.category,
                    areaName: machine.area?.name,
                    imageData: machine.imageData,
                    lastUsed: model.recentMachines.first(where: { $0.id == machine.id })?.lastTrained,
                    settingsComplete: !machine.sortedSettings.isEmpty,
                    action: { router.startWorkout(machineID: machine.id) }
                )

                coachInsightCard(for: machine)
            }
        } else if model.recentMachines.isEmpty {
            EmptyStateView(
                icon: "figure.strengthtraining.traditional",
                title: "No Workouts Yet",
                message: "Start your first session and your training history will appear here.",
                actionTitle: "Start Workout",
                action: { router.startWorkout() }
            )
        }
    }

    @ViewBuilder
    private func coachInsightCard(for machine: Machine) -> some View {
        let lastSetting = machine.sortedSettings.first
        let weightHint = lastSetting.map { "\($0.value)" } ?? "your last weight"
        CoachInsightCard(
            title: "Suggested for \(machine.name)",
            message: "Use \(weightHint) and aim for 3 sets of 10 reps. Increase load when all sets feel comfortable."
        )
    }

    // MARK: - Quick Actions

    @ViewBuilder
    private var quickActionsSection: some View {
        VStack(spacing: DS.Spacing.md) {
            PremiumSectionHeader("Quick Actions")
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: DS.Spacing.md),
                          GridItem(.flexible(), spacing: DS.Spacing.md)],
                spacing: DS.Spacing.md
            ) {
                QuickActionButton(
                    icon: "play.fill",
                    label: "Start Workout",
                    tint: DS.Palette.accent
                ) { router.startWorkout() }

                QuickActionButton(
                    icon: "qrcode.viewfinder",
                    label: "Scan Machine",
                    tint: DS.Palette.accentSecondary
                ) { showingScanFlow = true }

                QuickActionButton(
                    icon: "dumbbell.fill",
                    label: "Open Gym",
                    tint: DS.Palette.success
                ) { router.openGym() }

                QuickActionButton(
                    icon: "chart.line.uptrend.xyaxis",
                    label: "View Progress",
                    tint: DS.Palette.energy
                ) { router.openProgress() }
            }
        }
    }

    // MARK: - Health Snapshot

    @ViewBuilder
    private var healthSection: some View {
        VStack(spacing: DS.Spacing.md) {
            PremiumSectionHeader("Health", subtitle: "From Apple Health")
            HealthSnapshotCard(
                heartRate: model.heartRate,
                bodyWeightKg: model.bodyWeightKg,
                activeEnergyKcal: model.activeEnergyKcal,
                lastWorkoutMinutes: model.lastWorkoutMinutes
            )
        }
    }

    // MARK: - Recent Machines horizontal scroll

    @ViewBuilder
    private var recentMachinesSection: some View {
        if !model.recentMachines.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                PremiumSectionHeader(
                    "Recent Machines",
                    subtitle: "Tap to start a set",
                    actionTitle: "All",
                    action: { router.openGym() }
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.md) {
                        ForEach(model.recentMachines) { ref in
                            RecentMachineChip(ref: ref) {
                                router.startWorkout(machineID: ref.id)
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, DS.Spacing.xs)
                }
            }
        }
    }
}

// MARK: - QuickActionButton

/// A square tappable tile used in the 2-column Quick Actions grid.
private struct QuickActionButton: View {
    let icon: String
    let label: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 48)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))

                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(DS.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .strokeBorder(.white.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - RecentMachineChip

/// Compact vertical chip for the recent machines horizontal scroll.
private struct RecentMachineChip: View {
    let ref: MachineRef
    let action: () -> Void

    private var muscleColor: Color { DS.Muscle.color(for: ref.name) }
    private var muscleSymbol: String { DS.Muscle.symbol(for: ref.name) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.xs) {
                Image(systemName: muscleSymbol)
                    .font(.title3)
                    .foregroundStyle(muscleColor)
                    .frame(width: 48, height: 48)
                    .background(
                        muscleColor.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    )

                Text(ref.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text(ref.lastTrained, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 90)
            .padding(.vertical, DS.Spacing.md)
            .padding(.horizontal, DS.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(DS.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .strokeBorder(.white.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Train \(ref.name), last trained \(ref.lastTrained.formatted(date: .abbreviated, time: .omitted))")
    }
}

// MARK: - Preview

#Preview("Today — populated") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Workout.self, Machine.self, Gym.self, GymArea.self,
        configurations: config
    )
    let router = AppRouter()
    return TodayView()
        .modelContainer(container)
        .environment(router)
        .preferredColorScheme(.dark)
}

#Preview("Today — empty") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Workout.self, Machine.self, Gym.self, GymArea.self,
        configurations: config
    )
    let router = AppRouter()
    return TodayView()
        .modelContainer(container)
        .environment(router)
        .preferredColorScheme(.light)
}
