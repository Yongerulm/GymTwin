import SwiftUI
import SwiftData

/// Full detail screen for a single machine. Shows hero image, settings chips,
/// last session sets, coach insight, history, and a prominent "Start Workout" CTA.
struct MachineDetailView: View {

    // MARK: - Init

    let machine: Machine

    init(machine: Machine) {
        self.machine = machine
    }

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var model = MachineViewModel()
    @State private var showingEdit = false
    @State private var showingDeleteAlert = false
    @State private var writingTag = false
    @State private var writeResult: String?
    @State private var lastSession: WorkoutExercise?
    @State private var personalRecord: WorkoutSet?
    @State private var history: [WorkoutExercise] = []

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                heroImage
                    .padding(.horizontal, DS.Spacing.lg)

                VStack(spacing: DS.Spacing.lg) {
                    headerSection

                    startWorkoutButton

                    if !machine.sortedSettings.isEmpty {
                        settingsChipsCard
                    }

                    if let session = lastSession, !session.sortedSets.isEmpty {
                        lastSessionCard(session: session)
                    }

                    coachSection

                    nfcPlaceholderRow

                    if !history.isEmpty {
                        historyCard
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xxl)
            }
        }
        .background(GymBackground().ignoresSafeArea())
        .navigationTitle(machine.localizedName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarItems }
        .sheet(isPresented: $showingEdit, onDismiss: { model.refresh() }) {
            MachineEditView(machine: machine)
                .environment(\.modelContext, modelContext)
        }
        .alert("Delete Machine", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                model.deleteMachine(machine)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete \"\(machine.name)\" and all its settings. Training history is preserved.")
        }
        .task {
            model.bind(modelContext)
            loadHistory()
        }
    }

    // MARK: - Hero image

    @ViewBuilder
    private var heroImage: some View {
        let muscleSymbol = DS.Muscle.symbol(for: machine.area?.name ?? machine.category)
        let muscleColor = DS.Muscle.color(for: machine.area?.name ?? machine.category)

        Group {
            if let data = machine.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [muscleColor.opacity(0.70), muscleColor.opacity(0.30)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: muscleSymbol)
                            .font(.system(size: 52, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.90))
                        if !machine.category.isEmpty {
                            Text(machine.category.uppercased())
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.65))
                                .kerning(1.5)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 230)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.24), radius: 22, x: 0, y: 10)
        .accessibilityLabel(machine.imageData != nil ? "Machine photo for \(machine.name)" : "Machine icon — \(machine.category)")
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(machine.localizedName)
                .font(.title2.weight(.bold))
            HStack(spacing: DS.Spacing.sm) {
                if let areaName = machine.area?.name {
                    TagPill(
                        text: areaName,
                        systemImage: DS.Muscle.symbol(for: areaName),
                        tint: DS.Muscle.color(for: areaName)
                    )
                }
                if !machine.category.isEmpty {
                    TagPill(text: machine.category, systemImage: "tag.fill")
                }
            }
            if !machine.notes.isEmpty {
                Text(machine.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, DS.Spacing.xxs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Start Workout Button

    private var startWorkoutButton: some View {
        Button {
            router.startWorkout(machineID: machine.id)
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "figure.strengthtraining.traditional")
                Text("Start Workout")
            }
        }
        .buttonStyle(GradientButtonStyle())
        .accessibilityHint("Starts a workout pre-loaded with this machine")
    }

    // MARK: - Settings chips (hero of this screen)

    private var settingsChipsCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            SectionHeader("Preferred Settings", subtitle: "Your saved adjustments")

            // Flowing wrap-friendly grid using a fixed 2-column layout
            let settings = machine.sortedSettings
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                alignment: .leading,
                spacing: DS.Spacing.md
            ) {
                ForEach(settings) { setting in
                    MachineSettingChip(
                        title: setting.title,
                        value: setting.value.isEmpty ? "—" : setting.value,
                        tint: chipTint(at: setting.sortIndex)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
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
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 16, x: 0, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Preferred settings for \(machine.name)")
    }

    // Cycle through a small palette for visual variety
    private func chipTint(at index: Int) -> Color {
        let tints: [Color] = [
            DS.Palette.accent,
            DS.Palette.accentSecondary,
            DS.Palette.success,
            DS.Palette.rest
        ]
        return tints[index % tints.count]
    }

    // MARK: - Last session card

    private func lastSessionCard(session: WorkoutExercise) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                SectionHeader("Last Session") {
                    if let date = session.workout?.date {
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider().opacity(0.4)

                ForEach(Array(session.sortedSets.enumerated()), id: \.element.id) { index, set in
                    HStack {
                        Text("Set \(index + 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .leading)
                        Text(formatSet(set))
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(set.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .accessibilityLabel("Set \(index + 1): \(formatSet(set))")
                }
            }
        }
    }

    // MARK: - Coach / suggested set section

    @ViewBuilder
    private var coachSection: some View {
        if let pr = personalRecord {
            let prText = formatSet(pr)
            SuggestedSetCard(
                machineName: machine.name,
                weightText: formatWeight(pr.weight),
                repsText: "\(pr.repetitions)",
                note: "Personal record — \(prText)"
            )
        } else {
            CoachInsightCard(
                icon: "sparkles",
                title: "Track Your Progress",
                message: "Start a workout on this machine to record sets and build your personal baseline.",
                tint: DS.Palette.accent
            )
        }
    }

    // MARK: - NFC / QR identity placeholder

    private var nfcPlaceholderRow: some View {
        let code = (machine.machineCode ?? "").trimmingCharacters(in: .whitespaces)
        let hasCode = !code.isEmpty
        let canWrite = hasCode && NFCWriterService.isAvailable

        return Button {
            guard canWrite else { return }
            writeResult = nil
            writingTag = true
            Task {
                let ok = await NFCWriterService().write(urlString: "gymtwin://machine/\(code)")
                writingTag = false
                writeResult = ok
                    ? "Tag written ✓ — just tap it to load this machine, no scan window."
                    : "Couldn't write the tag. Hold it steady and try again."
            }
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "wave.3.right.circle.fill")
                    .font(.headline)
                    .foregroundStyle(canWrite ? DS.Palette.accent : Color.secondary)
                    .frame(width: 36, height: 36)
                    .background((canWrite ? DS.Palette.accent : Color.gray).opacity(0.12),
                               in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(writingTag ? "Hold near the tag…" : "Write NFC Tag")
                        .font(.subheadline.weight(.semibold))
                    Text(writeResult ?? rowSubtitle(hasCode: hasCode, code: code))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if writingTag {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(DS.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .strokeBorder(.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canWrite || writingTag)
        .accessibilityLabel(canWrite ? "Write an NFC tag for this machine" : "Set a machine code in Edit first to write a tag")
    }

    private func rowSubtitle(hasCode: Bool, code: String) -> String {
        if !NFCWriterService.isAvailable { return "NFC isn't available on this device" }
        if !hasCode { return "Set a machine code in Edit first" }
        return "Encodes gymtwin://machine/\(code) — then just tap the tag, no scan window"
    }

    // MARK: - History card

    private var historyCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                SectionHeader("History", subtitle: "\(history.count) session\(history.count == 1 ? "" : "s")")

                Divider().opacity(0.4)

                ForEach(history.prefix(5)) { exercise in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            if let date = exercise.workout?.date {
                                Text(date, style: .date)
                                    .font(.subheadline.weight(.medium))
                            }
                            Text("\(exercise.sets.count) set\(exercise.sets.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if exercise.topWeight > 0 {
                            Text(formatWeight(exercise.topWeight))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DS.Palette.accent)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(historyRowLabel(for: exercise))
                }

                if history.count > 5 {
                    Text("+ \(history.count - 5) more sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, DS.Spacing.xs)
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Edit") { showingEdit = true }
                .accessibilityLabel("Edit machine")
        }
        ToolbarItem(placement: .destructiveAction) {
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Image(systemName: "trash")
            }
            .accessibilityLabel("Delete machine")
        }
    }

    // MARK: - Data loading

    private func loadHistory() {
        let service = WorkoutService(context: modelContext)
        lastSession = service.lastSession(forMachineID: machine.id)
        personalRecord = service.personalRecord(forMachineID: machine.id)
        history = service.history(forMachineID: machine.id)
    }

    // MARK: - Formatting helpers

    private func formatSet(_ set: WorkoutSet) -> String {
        "\(formatWeight(set.weight)) × \(set.repetitions)"
    }

    private func formatWeight(_ weight: Double) -> String {
        let formatted = weight.formatted(.number.precision(.fractionLength(0...1)))
        return "\(formatted) kg"
    }

    private func historyRowLabel(for exercise: WorkoutExercise) -> String {
        let date = exercise.workout?.date.formatted(date: .abbreviated, time: .omitted) ?? ""
        let sets = "\(exercise.sets.count) set\(exercise.sets.count == 1 ? "" : "s")"
        let weight = exercise.topWeight > 0 ? ", top weight \(formatWeight(exercise.topWeight))" : ""
        return [date, sets].filter { !$0.isEmpty }.joined(separator: ", ") + weight
    }
}

// MARK: - Preview

#Preview {
    let machine = Machine(name: "Chest Press", category: "Chest", notes: "Seat at level 4", sortIndex: 0)
    machine.settings = [
        MachineSetting(title: "Seat Height", value: "4", sortIndex: 0),
        MachineSetting(title: "Weight", value: "57.5 kg", sortIndex: 1),
        MachineSetting(title: "Grip", value: "Wide", sortIndex: 2)
    ]
    return NavigationStack {
        MachineDetailView(machine: machine)
            .environment(AppRouter())
    }
    .preferredColorScheme(.dark)
}
