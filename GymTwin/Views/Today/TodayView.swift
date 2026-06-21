import SwiftUI
import SwiftData

/// Today tab — the emotional and functional home of the app.
/// One NavigationStack with a scrollable composition of premium cards.
struct TodayView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(GymSelection.self) private var gymSelection
    @Query(sort: \WorkoutPlan.sortIndex) private var plans: [WorkoutPlan]
    @Query private var gyms: [Gym]

    @State private var model = TodayViewModel()
    @State private var showingScanFlow = false
    @State private var pendingDraft: WorkoutDraft?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: DS.Spacing.xl) {
                    if let draft = pendingDraft, !router.isWorkoutActive {
                        resumeBar(draft)
                    }
                    heroSection
                    trainNowSection
                    healthSection
                    recentMachinesSection
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xl)
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .background(GymBackground().ignoresSafeArea())
            .toolbar { gymChip }
        }
        .task {
            model.bind(modelContext)
        }
        .onAppear {
            model.refresh()
            pendingDraft = WorkoutDraftStore.load()
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
            streakDays: model.statistics.currentStreakDays,
            readinessText: model.readinessTitle
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

    // MARK: - Gym context chip (which gym am I at)

    @ToolbarContentBuilder
    private var gymChip: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if !gyms.isEmpty {
                let active = gymSelection.activeGym(from: gyms)
                Menu {
                    ForEach(gyms) { gym in
                        Button {
                            gymSelection.activeGymID = gym.id
                        } label: {
                            Label(gym.name, systemImage: active?.id == gym.id ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse").font(.caption2)
                        Text(active?.name ?? "Gym").font(.subheadline.weight(.semibold))
                        if gyms.count > 1 { Image(systemName: "chevron.down").font(.caption2) }
                    }
                    .foregroundStyle(DS.Palette.accent)
                }
                .accessibilityLabel("Current gym: \(active?.name ?? "none"). Tap to switch.")
            }
        }
    }

    // MARK: - Resume in-progress session

    private func resumeBar(_ draft: WorkoutDraft) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.headline).foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(DS.Palette.accentGradient, in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Resume workout").font(.subheadline.weight(.bold))
                Text("\(draft.exercises.count) exercise\(draft.exercises.count == 1 ? "" : "s") · \(draft.totalSets) sets logged")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { WorkoutDraftStore.clear(); pendingDraft = nil } label: {
                Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Discard in-progress workout")
        }
        .padding(DS.Spacing.md)
        .background(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).fill(DS.Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).strokeBorder(DS.Palette.accent.opacity(0.4), lineWidth: 1.5))
        .shadow(color: DS.Palette.accent.opacity(0.18), radius: 10, x: 0, y: 4)
        .contentShape(Rectangle())
        .onTapGesture { router.resumeWorkout() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Resume your in-progress workout — \(draft.exercises.count) exercises, \(draft.totalSets) sets logged")
    }

    // MARK: - Train now — one-tap plan launchpad

    @ViewBuilder
    private var trainNowSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            PremiumSectionHeader("Start training", subtitle: "Tap a plan — your weights load instantly")

            if plans.isEmpty {
                Button { router.openGym() } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "plus.circle.fill").foregroundStyle(DS.Palette.accent)
                        Text("Build your first plan in Train")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(DS.Palette.accent)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    .padding(DS.Spacing.lg)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).fill(DS.Palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).strokeBorder(DS.Palette.accent.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [6])))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Build your first plan")
            }

            ForEach(plans) { plan in
                Button {
                    router.startWorkout(planID: plan.id.uuidString)
                } label: {
                    planStartCard(name: plan.name, count: plan.exercises.count)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start \(plan.name), \(plan.exercises.count) machines")
            }

            // Free / scan-first session.
            Button { router.startScan() } label: {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "bolt.fill")
                        .font(.headline).foregroundStyle(DS.Palette.accent)
                        .frame(width: 38, height: 38)
                        .background(DS.Palette.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Free session").font(.subheadline.weight(.bold))
                        Text("No plan — scan or add machines as you go").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .padding(DS.Spacing.lg)
                .background(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).fill(DS.Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start a free session")
        }
    }

    private func planStartCard(name: String, count: Int) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "play.fill")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(DS.Palette.accentGradient, in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                .shadow(color: DS.Palette.accent.opacity(0.35), radius: 8, x: 0, y: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.headline.weight(.bold))
                Text("\(count) machine\(count == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(DS.Spacing.lg)
        .background(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).fill(DS.Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).strokeBorder(DS.Palette.accent.opacity(0.18), lineWidth: 1))
    }

    // MARK: - Scan Machine button

    private var scanMachineButton: some View {
        Button {
            showingScanFlow = true
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color(hex: "#1A0700"))
                    .frame(width: 40, height: 40)
                    .background(DS.Palette.accent, in: RoundedRectangle(cornerRadius: 11, style: .continuous))

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
            // Start + Scan live in the hero and the scan row above, so the
            // quick actions are just navigation shortcuts (no duplicate Start).
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: DS.Spacing.md),
                          GridItem(.flexible(), spacing: DS.Spacing.md)],
                spacing: DS.Spacing.md
            ) {
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

    private var muscleSymbol: String { DS.Muscle.symbol(for: ref.name) }

    var body: some View {
        Button(action: action) {
            // Ember: solid area-gradient chip with a white stroke icon + label.
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: muscleSymbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                Text(LocalizedNames.machineName(ref.name))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 76, height: 84)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DS.Muscle.gradient(for: ref.name))
                    .overlay(
                        LinearGradient(colors: [.white.opacity(0.14), .clear], startPoint: .top, endPoint: .center)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    )
            )
            .shadow(color: DS.Muscle.glow(for: ref.name).opacity(0.32), radius: 8, x: 0, y: 5)
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
