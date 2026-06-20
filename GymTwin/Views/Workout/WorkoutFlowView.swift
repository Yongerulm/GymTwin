import SwiftUI
import SwiftData

/// Full-screen workout flow. Presented over any tab via `AppRouter.isWorkoutActive`.
/// Owns its own `NavigationStack` and `WorkoutViewModel`.
struct WorkoutFlowView: View {
    let initialMachineID: UUID?
    /// Scan-first entry (Scan tab): skip the program picker, train freely.
    var scanMode: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(GymSelection.self) private var gymSelection
    @Query private var gyms: [Gym]
    @Query private var plans: [WorkoutPlan]
    @AppStorage("active.plan.id") private var activePlanID: String = ""
    /// User's preferred rest length in seconds (flexible, persisted).
    @AppStorage("rest.duration.seconds") private var restDuration: Int = 90

    @State private var model = WorkoutViewModel()
    @State private var showingMachinePicker = false
    @State private var showingManualCode = false
    @State private var manualCode = ""
    @State private var showingFinishConfirm = false
    @State private var showingRestTimer = false
    @State private var setEntryTarget: SetEntryTarget?

    /// Hands-free mode: keep the NFC reader armed so walking up to a machine
    /// and tapping the phone loads it. Off by default — scanning is always
    /// user-initiated, so the NFC sheet never opens unprompted on launch.
    @State private var continuousScan = false
    @State private var scanTask: Task<Void, Never>?

    /// Gates the session behind an explicit program choice. Until the user
    /// picks a plan (or free training), the program picker is shown instead of
    /// the session — so "Start Workout" never auto-loads a stale active plan.
    @State private var programChosen = false

    /// Transient "machine detected" banner shown on a successful scan, paired
    /// with a success haptic — the near-invisible NFC feedback.
    @State private var detectedMachineName: String?
    @State private var detectBannerTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if !programChosen {
                    programSelection
                } else if model.exercises.isEmpty && activePlan == nil {
                    emptyPrompt
                } else {
                    sessionContent
                }
            }
            .navigationTitle(programChosen ? timerString : "Start Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
            .background(GymBackground().ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                if programChosen { bottomBar }
            }
            .overlay(alignment: .top) { detectionBanner }
        }
        .task {
            model.bind(modelContext)
            if let id = initialMachineID {
                // Started from a specific machine — skip the picker.
                if !model.isActive { model.start() }
                model.addExerciseByID(id)
                programChosen = true
            } else if scanMode {
                // Scan tab — free training, no plan, no auto-scan sheet.
                activePlanID = ""
                if !model.isActive { model.start() }
                programChosen = true
            }
            // Otherwise wait for the user to choose a program (no scanning).
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
            ) { weight, reps, type in
                model.addSet(weight: weight, reps: reps, type: type, toExerciseAt: target.exerciseIndex)
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

    // MARK: - Program selection (first step of Start Workout)

    private var sortedPlans: [WorkoutPlan] {
        plans.sorted { $0.sortIndex < $1.sortIndex }
    }

    private var programSelection: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                VStack(spacing: DS.Spacing.xs) {
                    Text("Choose your program")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text("Follow a saved plan, or train freely and scan machines as you go.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DS.Spacing.lg)
                .padding(.horizontal, DS.Spacing.lg)

                // Free training — no plan.
                programCard(
                    title: "Free Training",
                    subtitle: "No plan — scan or add machines as you go",
                    systemImage: "bolt.fill",
                    tint: DS.Palette.accent
                ) { chooseFreeTraining() }

                // Saved plans.
                ForEach(sortedPlans) { plan in
                    programCard(
                        title: plan.name,
                        subtitle: planSubtitle(plan),
                        systemImage: "list.bullet.rectangle.portrait.fill",
                        tint: DS.Palette.accentSecondary
                    ) { chooseProgram(plan) }
                }

                if sortedPlans.isEmpty {
                    Text("Build training plans in the Workouts tab to follow them here.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.xl)
                        .padding(.top, DS.Spacing.sm)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xxl)
        }
    }

    private func planSubtitle(_ plan: WorkoutPlan) -> String {
        let count = plan.exercises.count
        let sets = plan.exercises.reduce(0) { $0 + $1.targetSets }
        return "\(count) exercise\(count == 1 ? "" : "s") · \(sets) sets"
    }

    private func programCard(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            SurfaceCard {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(width: 46, height: 46)
                        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.headline.weight(.bold))
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: DS.Spacing.sm)
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(subtitle)")
    }

    /// Free training: clear any active plan, start an empty session.
    private func chooseFreeTraining() {
        activePlanID = ""
        if !model.isActive { model.start() }
        withAnimation(DS.Motion.spring) { programChosen = true }
    }

    /// Load the chosen plan as the active program and pre-populate the session
    /// with all its exercises, then enter the guided session.
    private func chooseProgram(_ plan: WorkoutPlan) {
        activePlanID = plan.id.uuidString
        if !model.isActive { model.start() }
        for planExercise in plan.sortedExercises {
            model.addExerciseByID(planExercise.machineID)
        }
        withAnimation(DS.Motion.spring) { programChosen = true }
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
                // Guided plan banner — current exercise/set/target + Complete Set.
                if let plan = activePlan {
                    guidedBanner(plan)
                }
                // Exercise cards (skip the one mirrored in the guided banner)
                ForEach(Array(model.exercises.enumerated()), id: \.element.id) { index, exercise in
                    if exercise.machineID != currentGuidedMachineID {
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

            RestTimerView(durationSeconds: $restDuration) {
                // Auto-dismiss after rest finishes
                showingRestTimer = false
            } onSkip: {
                // Skip → jump straight to the next set.
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
        if programChosen {
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

    // MARK: - Detection banner (near-invisible NFC feedback)

    @ViewBuilder
    private var detectionBanner: some View {
        if let name = detectedMachineName {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "wave.3.right.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DS.Palette.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Machine detected")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text(name)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(DS.Palette.accent.opacity(0.35), lineWidth: 1))
            .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.sm)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Machine detected: \(name)")
        }
    }

    /// Show the detection banner with a success haptic, then auto-hide it.
    @MainActor
    private func flashDetection(_ name: String) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        detectBannerTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            detectedMachineName = name
        }
        detectBannerTask = Task {
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                detectedMachineName = nil
            }
        }
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

        flashDetection(machine.name)

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

    // MARK: - Guided workout mode

    /// The user's currently active training plan, if one is selected.
    private var activePlan: WorkoutPlan? {
        guard !activePlanID.isEmpty else { return nil }
        return plans.first { $0.id.uuidString == activePlanID }
    }

    /// Machine id of the exercise currently shown in the guided banner — its
    /// own card is hidden so the same exercise never appears twice.
    private var currentGuidedMachineID: UUID? {
        guard let plan = activePlan else { return nil }
        return guidedStep(plan)?.exercise.machineID
    }

    /// Completed set count for a planned machine in the live session.
    private func completedSets(forMachineID id: UUID) -> Int {
        model.exercises.first(where: { $0.machineID == id })?.sets.count ?? 0
    }

    /// The next planned step to perform, or nil when the plan is complete.
    private func guidedStep(_ plan: WorkoutPlan) -> (exercise: PlanExercise, index: Int, setNumber: Int)? {
        let sorted = plan.sortedExercises
        for (i, pe) in sorted.enumerated() where completedSets(forMachineID: pe.machineID) < pe.targetSets {
            return (pe, i, completedSets(forMachineID: pe.machineID) + 1)
        }
        return nil
    }

    /// Log a planned set at its target and start the rest timer.
    private func completeGuidedSet(_ target: PlanExercise) {
        if !model.isActive { model.start() }
        if !model.exercises.contains(where: { $0.machineID == target.machineID }) {
            model.addExerciseByID(target.machineID)
        }
        guard let idx = model.exercises.firstIndex(where: { $0.machineID == target.machineID }) else { return }
        model.addSet(weight: target.targetWeight, reps: target.targetReps, type: .working, toExerciseAt: idx)
        showingRestTimer = true
    }

    @ViewBuilder
    private func guidedBanner(_ plan: WorkoutPlan) -> some View {
        SurfaceCard {
            if let step = guidedStep(plan) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack {
                        Text(plan.name)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(DS.Palette.accent)
                            .textCase(.uppercase)
                            .tracking(0.6)
                        Spacer()
                        Text("Exercise \(step.index + 1)/\(plan.sortedExercises.count)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text(step.exercise.machineName).font(.title2.weight(.bold))
                    HStack(spacing: DS.Spacing.xl) {
                        guidedStat("Set", "\(step.setNumber)/\(step.exercise.targetSets)")
                        guidedStat("Target", "\(step.exercise.targetReps) reps")
                        guidedStat("Weight", "\(weightText(step.exercise.targetWeight)) kg")
                    }
                    Button {
                        completeGuidedSet(step.exercise)
                    } label: {
                        Label("Complete Set", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(GradientButtonStyle())
                }
            } else {
                VStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(DS.Palette.success)
                    Text("Plan complete — great work!")
                        .font(.headline.weight(.bold))
                    Text("Finish your workout, or add extra sets below.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func guidedStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline.weight(.bold)).monospacedDigit().contentTransition(.numericText())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func weightText(_ w: Double) -> String {
        w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w)
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

// MARK: - Preview

#Preview("WorkoutFlowView — empty") {
    WorkoutFlowView(initialMachineID: nil)
        .environment(AppRouter())
        .preferredColorScheme(.dark)
}
