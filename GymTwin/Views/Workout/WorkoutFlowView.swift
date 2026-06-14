import SwiftUI
import SwiftData

/// Full-screen workout flow. Presented over any tab via `AppRouter.isWorkoutActive`.
/// Owns its own `NavigationStack` and `WorkoutViewModel`.
struct WorkoutFlowView: View {
    let initialMachineID: UUID?

    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(GymSelection.self) private var gymSelection
    @Query private var gyms: [Gym]
    @Query private var plans: [WorkoutPlan]
    @AppStorage("active.plan.id") private var activePlanID: String = ""

    @State private var model = WorkoutViewModel()
    @State private var showingMachinePicker = false
    @State private var showingManualCode = false
    @State private var manualCode = ""
    @State private var showingFinishConfirm = false
    @State private var showingRestTimer = false
    @State private var setEntryTarget: SetEntryTarget?

    /// Hands-free mode: keep the NFC reader armed so walking up to a machine
    /// and tapping the phone loads it — no button press per machine.
    @State private var continuousScan = true
    @State private var scanTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if model.exercises.isEmpty {
                    emptyPrompt
                } else {
                    sessionContent
                }
            }
            .navigationTitle(timerString)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
            .background(GymBackground().ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { bottomBar }
        }
        .task {
            model.bind(modelContext)
            if !model.isActive { model.start() }
            if let id = initialMachineID {
                model.addExerciseByID(id)
            }
            armContinuousScan()
        }
        .onChange(of: setEntryTarget?.id) { _, newValue in
            // When the set-entry sheet closes, re-arm scanning for the next machine.
            if newValue == nil { armContinuousScan() }
        }
        .onChange(of: continuousScan) { _, isOn in
            if isOn { armContinuousScan() } else { scanTask?.cancel(); scanTask = nil }
        }
        .onDisappear { scanTask?.cancel(); scanTask = nil }
        .sheet(item: $setEntryTarget) { target in
            WorkoutSetEntryView(
                exerciseName: target.exerciseName,
                lastWeight: target.lastWeight,
                lastReps: target.lastReps,
                machineID: target.machineID
            ) { weight, reps in
                model.addSet(weight: weight, reps: reps, toExerciseAt: target.exerciseIndex)
                setEntryTarget = nil
            } onCancel: {
                setEntryTarget = nil
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingMachinePicker) {
            WorkoutMachinePicker { machine in
                if !model.isActive { model.start() }
                model.addExercise(machine: machine)
                showingMachinePicker = false
            } onDismiss: {
                showingMachinePicker = false
            }
        }
        .alert("Machine code", isPresented: $showingManualCode) {
            TextField("e.g. sscp", text: $manualCode)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Load") {
                let code = manualCode.trimmingCharacters(in: .whitespaces)
                manualCode = ""
                guard !code.isEmpty else { return }
                Task { await loadScannedMachine(rawCode: code) }
            }
            Button("Cancel", role: .cancel) { manualCode = "" }
        } message: {
            Text("NFC needs a real device — enter a machine code to test the flow.")
        }
        .sheet(isPresented: $showingRestTimer) {
            restTimerSheet
        }
        .confirmationDialog(
            "Finish Workout?",
            isPresented: $showingFinishConfirm,
            titleVisibility: .visible
        ) {
            Button("Save & Finish", role: .none) {
                model.finish()
                router.endWorkout()
            }
            Button("Discard Session", role: .destructive) {
                model.reset()
                router.endWorkout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your session will be saved and synced to Health.")
        }
    }

    // MARK: - Empty prompt

    private var emptyPrompt: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            Image(systemName: "wave.3.right.circle.fill")
                .font(.system(size: 58))
                .foregroundStyle(DS.Palette.accentGradient)
            VStack(spacing: DS.Spacing.xs) {
                Text("Scan a machine to begin")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("Hold your iPhone to a machine's NFC tag — its preferred weights load automatically, ready to adjust.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DS.Spacing.lg)

            Button {
                quickScan()
            } label: {
                Label("Scan Machine", systemImage: "wave.3.right")
            }
            .buttonStyle(GradientButtonStyle())
            .padding(.horizontal, DS.Spacing.xl)

            Button("Add manually") {
                if !model.isActive { model.start() }
                showingMachinePicker = true
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(DS.Palette.accent)

            Spacer()
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Session content

    private var sessionContent: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                // Exercise cards
                ForEach(Array(model.exercises.enumerated()), id: \.element.id) { index, exercise in
                    ExerciseSessionCard(
                        exercise: exercise,
                        exerciseIndex: index,
                        lastSession: model.lastSession(forMachineID: exercise.machineID),
                        onAddSet: {
                            let last = exercise.sets.last
                            setEntryTarget = SetEntryTarget(
                                exerciseIndex: index,
                                exerciseName: exercise.machineName,
                                lastWeight: last?.weight ?? 20,
                                lastReps: last?.reps ?? 10,
                                machineID: exercise.machineID
                            )
                        },
                        onRepeatSet: {
                            // Copy the last set (weight + reps) and start the
                            // rest/pause timer, so repeated sets are one tap.
                            if model.repeatLastSet(forExerciseAt: index) != nil {
                                showingRestTimer = true
                            }
                        },
                        onRemoveSet: { setID in
                            model.removeSet(id: setID, fromExerciseAt: index)
                        },
                        onRemoveExercise: {
                            model.removeExercise(id: exercise.id)
                        }
                    )
                }

                // Add machine dashed button
                addMachineButton

                // Rest timer inline toggle
                restTimerToggle
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, 120)
        }
    }

    // MARK: - Add machine button

    private var addMachineButton: some View {
        Button {
            showingMachinePicker = true
        } label: {
            Label("Add Machine", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.Palette.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .strokeBorder(
                            DS.Palette.accent.opacity(0.4),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6])
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add a machine to the current session")
    }

    // MARK: - Rest timer toggle

    private var restTimerToggle: some View {
        Button {
            showingRestTimer = true
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "timer")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.Palette.rest)
                Text("Rest Timer")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.Palette.rest)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(DS.Palette.rest.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open rest timer")
    }

    // MARK: - Rest timer sheet

    private var restTimerSheet: some View {
        VStack(spacing: DS.Spacing.xl) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, DS.Spacing.md)

            RestTimerView(durationSeconds: 90) {
                // Auto-dismiss after rest finishes
                showingRestTimer = false
            }
            .padding(.horizontal, DS.Spacing.lg)

            Spacer()
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .background(GymBackground().ignoresSafeArea())
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.3)
            HStack(spacing: DS.Spacing.md) {
                // Minimal NFC scan button — a quick tap loads the next machine.
                Button {
                    quickScan()
                } label: {
                    Image(systemName: "wave.3.right")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(DS.Palette.accent)
                        .frame(width: 56, height: 56)
                        .background(
                            DS.Palette.accent.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Scan a machine with NFC")

                // Finish / Discard
                Button {
                    if model.exercises.isEmpty {
                        model.reset()
                        router.endWorkout()
                    } else {
                        showingFinishConfirm = true
                    }
                } label: {
                    Label(
                        model.exercises.isEmpty ? "Discard" : "Finish",
                        systemImage: model.exercises.isEmpty ? "xmark" : "checkmark.circle.fill"
                    )
                }
                .buttonStyle(GradientButtonStyle())
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
        }
        .background(.regularMaterial)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Label(timerString, systemImage: "timer")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(DS.Palette.accent)
                .contentTransition(.numericText())
                .animation(.default, value: model.elapsedSeconds)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            if NFCService.isAvailable {
                Button {
                    continuousScan.toggle()
                } label: {
                    Image(systemName: continuousScan ? "wave.3.right.circle.fill" : "wave.3.right.circle")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(continuousScan ? DS.Palette.accent : .secondary)
                }
                .accessibilityLabel(continuousScan ? "Hands-free scanning on" : "Hands-free scanning off")
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                model.reset()
                router.endWorkout()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Cancel workout")
        }
    }

    // MARK: - Timer string

    private var timerString: String {
        let h = model.elapsedSeconds / 3600
        let m = (model.elapsedSeconds % 3600) / 60
        let s = model.elapsedSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Continuous (hands-free) scanning

    /// Arm the NFC reader so the next machine the user taps loads automatically.
    /// Re-arms itself after each machine via the `setEntryTarget` change hook.
    /// No-op in the Simulator (no NFC) — there the manual "Scan" sheet is used.
    private func armContinuousScan() {
        guard continuousScan, NFCService.isAvailable, setEntryTarget == nil, scanTask == nil else { return }
        scanTask = Task {
            let code = await NFCService().scan()
            scanTask = nil
            if let code {
                await loadScannedMachine(rawCode: code)
            } else {
                // The user dismissed the system NFC sheet — leave hands-free mode.
                continuousScan = false
            }
        }
    }

    // MARK: - Scan → load machine with predefined weights

    /// Resolve a scanned/typed machine code, add it to the running session, and
    /// open set entry pre-filled with that machine's predefined (suggested)
    /// weight + reps — ready for the user to adjust.
    private func loadScannedMachine(rawCode: String) async {
        guard let code = MachineRecognitionService.parseMachineCode(from: rawCode) else { return }
        if !model.isActive { model.start() }

        // Existing personal machine for this code?
        let existing = (try? modelContext.fetch(
            FetchDescriptor<Machine>(predicate: #Predicate { $0.machineCode == code })
        ))?.first

        let machine: Machine
        if let existing {
            machine = existing
        } else {
            // Create from the equipment library (or a bare entry) and file it
            // under the active gym.
            let def = try? await LocalMachineRepository().machine(forCode: code)
            let new = Machine(
                name: def?.name ?? "Machine \(code.uppercased())",
                category: def?.category ?? "",
                machineCode: code
            )
            modelContext.insert(new)
            attachToActiveGym(new, category: def?.category)
            try? modelContext.save()
            machine = new
        }

        model.addExercise(machine: machine)
        guard let index = model.exercises.firstIndex(where: { $0.machineID == machine.id }) else { return }

        // Prefer the active plan's predefined target for this machine; otherwise
        // the coach's suggestion (last session / rule).
        let weight: Double
        let reps: Int
        if let target = activePlanTarget(for: machine) {
            weight = target.targetWeight
            reps = target.targetReps
        } else {
            let suggestion = CoachService(context: modelContext).nextSet(forMachineID: machine.id, goal: .muscleGain)
            weight = suggestion.weight > 0 ? suggestion.weight : 20
            reps = suggestion.reps
        }
        setEntryTarget = SetEntryTarget(
            exerciseIndex: index,
            exerciseName: machine.name,
            lastWeight: weight,
            lastReps: reps,
            machineID: machine.id
        )
    }

    /// Quick NFC scan with no custom window: triggers the system NFC sheet on a
    /// real device, or a small code prompt in the Simulator.
    private func quickScan() {
        if !model.isActive { model.start() }
        if NFCService.isAvailable {
            Task {
                if let code = await NFCService().scan() {
                    await loadScannedMachine(rawCode: code)
                }
            }
        } else {
            showingManualCode = true
        }
    }

    /// The active plan's target for a machine, matched by id or scanned code.
    private func activePlanTarget(for machine: Machine) -> PlanExercise? {
        guard !activePlanID.isEmpty,
              let plan = plans.first(where: { $0.id.uuidString == activePlanID }) else { return nil }
        if let byID = plan.target(forMachineID: machine.id) { return byID }
        if let code = machine.machineCode { return plan.target(forCode: code) }
        return nil
    }

    /// Files a freshly created machine under the active gym, in an area that
    /// matches its category when possible.
    private func attachToActiveGym(_ machine: Machine, category: String?) {
        guard let gym = gymSelection.activeGym(from: gyms) else { return }
        let areas = gym.sortedAreas
        let target = areas.first { area in
            guard let category, !category.isEmpty else { return false }
            return area.name.lowercased() == category.lowercased()
        } ?? areas.first
        machine.area = target
    }
}

// MARK: - SetEntryTarget (sheet coordination)

private struct SetEntryTarget: Identifiable {
    let id = UUID()
    let exerciseIndex: Int
    let exerciseName: String
    let lastWeight: Double
    let lastReps: Int
    /// Machine UUID forwarded to `WorkoutSetEntryView` so it can load an AI hint.
    var machineID: UUID?
}

// MARK: - ExerciseSessionCard

private struct ExerciseSessionCard: View {
    let exercise: DraftExercise
    let exerciseIndex: Int
    let lastSession: WorkoutExercise?
    let onAddSet: () -> Void
    let onRepeatSet: () -> Void
    let onRemoveSet: (UUID) -> Void
    let onRemoveExercise: () -> Void

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
                        Text(exercise.machineName)
                            .font(.headline.weight(.bold))
                        if !exercise.sets.isEmpty {
                            Text("\(exercise.sets.count) set\(exercise.sets.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button(role: .destructive, action: onRemoveExercise) {
                        Image(systemName: "trash")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                    }
                    .accessibilityLabel("Remove \(exercise.machineName) from session")
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

                // Add Set + Repeat last set
                HStack(spacing: DS.Spacing.sm) {
                    Button(action: onAddSet) {
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
        }
    }

    private func formatSet(weight: Double, reps: Int) -> String {
        let w = weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f kg", weight)
            : String(format: "%.1f kg", weight)
        return "\(w) × \(reps)"
    }
}

// MARK: - LoggedSetRow

private struct LoggedSetRow: View {
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

// MARK: - Preview

#Preview("WorkoutFlowView — empty") {
    WorkoutFlowView(initialMachineID: nil)
        .environment(AppRouter())
        .preferredColorScheme(.dark)
}
