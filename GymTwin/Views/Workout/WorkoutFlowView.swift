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
    // Sticky in-session rest: countdown lives here (not in a sheet) so it stays
    // glanceable above the action bar between sets.
    @State private var restActive = false
    @State private var restRemaining = 0
    @State private var restTask: Task<Void, Never>?
    @State private var summary: SessionSummaryData?
    /// Exercise pending a remove confirmation (prevents accidental deletion).
    @State private var pendingRemoveID: UUID?
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
                VStack(spacing: 0) {
                    if restActive { restStrip }
                    if programChosen { bottomBar }
                }
                .animation(DS.Motion.spring, value: restActive)
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
        .onDisappear { scanTask?.cancel(); scanTask = nil; restTask?.cancel() }
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
                finishWithSummary()
            }
            Button("Discard Session", role: .destructive) {
                model.reset()
                router.endWorkout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your session will be saved and synced to Health.")
        }
        .confirmationDialog(
            "Remove exercise?",
            isPresented: Binding(get: { pendingRemoveID != nil }, set: { if !$0 { pendingRemoveID = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let id = pendingRemoveID { model.removeExercise(id: id) }
                pendingRemoveID = nil
            }
            Button("Keep", role: .cancel) { pendingRemoveID = nil }
        } message: {
            Text("This removes the exercise and its logged sets from this session.")
        }
        .sheet(item: $summary) { data in
            SessionSummaryView(
                durationMinutes: data.durationMinutes,
                exerciseCount: data.exerciseCount,
                totalSets: data.totalSets,
                totalVolume: data.totalVolume,
                volumeDeltaPercent: data.volumeDeltaPercent,
                newPRs: data.newPRs,
                streakDays: data.streakDays
            ) {
                summary = nil
                router.endWorkout()
            }
            .interactiveDismissDisabled()
        }
    }

    // MARK: - Finish with post-session summary

    /// Persist the session, then surface the celebratory summary (the habit
    /// moment) before returning to the app.
    private func finishWithSummary() {
        guard let workout = model.finish() else { router.endWorkout(); return }
        let service = WorkoutService(context: modelContext)
        // Volume change vs the previous saved workout.
        let history = service.allWorkouts()
        let previous = history.first { $0.id != workout.id }
        let delta: Double? = {
            guard let prevVol = previous?.totalVolume, prevVol > 0 else { return nil }
            return (workout.totalVolume - prevVol) / prevVol * 100
        }()
        summary = SessionSummaryData(
            durationMinutes: max(1, Int(workout.duration / 60)),
            exerciseCount: workout.exercises.count,
            totalSets: workout.totalSets,
            totalVolume: workout.totalVolume,
            volumeDeltaPercent: delta,
            newPRs: [],
            streakDays: service.statistics().currentStreakDays
        )
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
        // Load every planned exercise (including duplicate machines) with its
        // predefined target, so the whole program is laid out to work through.
        for pe in plan.sortedExercises {
            model.addPlannedExercise(
                machineID: pe.machineID,
                machineName: pe.machineName,
                planExerciseID: pe.id,
                targetSets: pe.targetSets,
                targetReps: pe.targetReps,
                targetWeight: pe.targetWeight
            )
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
                // Slim plan progress header (no duplicated banner card).
                if let plan = activePlan {
                    planProgressHeader(plan)
                }
                // One card per exercise — each shows its predefined target and a
                // Complete Set button so the program is worked through top-down.
                ForEach(Array(model.exercises.enumerated()), id: \.element.id) { index, exercise in
                    ExerciseSessionCard(
                        exercise: exercise,
                        exerciseIndex: index,
                        isActive: index == activeExerciseIndex,
                        lastSession: model.lastSession(forMachineID: exercise.machineID),
                        onCompleteSet: exercise.targetWeight != nil ? { completePlannedSet(at: index) } : nil,
                        onLogSet: { weight, reps, type in
                            model.addSet(weight: weight, reps: reps, type: type, toExerciseAt: index)
                            startRest()
                        },
                        coachHint: index == activeExerciseIndex ? coachHint(forMachineID: exercise.machineID) : nil,
                        onAddSet: {
                            let last = exercise.sets.last
                            setEntryTarget = SetEntryTarget(
                                exerciseIndex: index,
                                exerciseName: exercise.machineName,
                                lastWeight: last?.weight ?? exercise.targetWeight ?? 20,
                                lastReps: last?.reps ?? exercise.targetReps ?? 10,
                                machineID: exercise.machineID
                            )
                        },
                        onRepeatSet: {
                            // Copy the last set (weight + reps) and start the
                            // rest/pause timer, so repeated sets are one tap.
                            if model.repeatLastSet(forExerciseAt: index) != nil {
                                startRest()
                            }
                        },
                        onRemoveSet: { setID in
                            model.removeSet(id: setID, fromExerciseAt: index)
                        },
                        onRemoveExercise: {
                            pendingRemoveID = exercise.id
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

    // MARK: - Plan progress + complete planned set

    /// Index of the current exercise to train: the first one whose predefined
    /// target sets aren't met yet (plan exercises only).
    private var activeExerciseIndex: Int? {
        model.exercises.firstIndex { $0.targetSets != nil && !$0.isPlanComplete }
    }

    /// Slim header showing the plan name and how many exercises are done.
    private func planProgressHeader(_ plan: WorkoutPlan) -> some View {
        let total = model.exercises.count
        let done = model.exercises.filter(\.isPlanComplete).count
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.name.uppercased())
                    .font(.system(size: 9, weight: .semibold)).tracking(1)
                    .foregroundStyle(DS.Palette.accent)
                Text("Work through your program")
                    .font(.subheadline.weight(.bold))
            }
            Spacer()
            Text("\(done)/\(total)")
                .font(.headline.weight(.bold).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One-line progressive-overload nudge for the active exercise, or nil when
    /// there's no history to reason about yet.
    private func coachHint(forMachineID id: UUID) -> String? {
        let coach = CoachService(context: modelContext)
        guard !coach.history(forMachineID: id).isEmpty else { return nil }
        return coach.progression(forMachineID: id, goal: .muscleGain).message
    }

    /// Log a set at the exercise's predefined target and start the rest timer.
    private func completePlannedSet(at index: Int) {
        guard model.exercises.indices.contains(index),
              let weight = model.exercises[index].targetWeight,
              let reps = model.exercises[index].targetReps else { return }
        model.addSet(weight: weight, reps: reps, type: .working, toExerciseAt: index)
        startRest()
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

    // MARK: - Sticky rest strip

    private var restTimeString: String {
        String(format: "%d:%02d", restRemaining / 60, restRemaining % 60)
    }

    /// Start the inline rest countdown from the user's preferred length.
    private func startRest() {
        restTask?.cancel()
        restRemaining = max(5, restDuration)
        restActive = true
        restTask = Task { @MainActor in
            while restRemaining > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { break }
                restRemaining -= 1
            }
            if !Task.isCancelled { restActive = false }
        }
    }

    private func skipRest() {
        restTask?.cancel(); restTask = nil
        restActive = false; restRemaining = 0
    }

    private func extendRest(_ seconds: Int) {
        restRemaining = max(0, restRemaining + seconds)
        if restRemaining == 0 { skipRest() }
    }

    /// Glanceable rest countdown shown above the action bar while resting.
    private var restStrip: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "timer").font(.headline).foregroundStyle(DS.Palette.rest)
            VStack(alignment: .leading, spacing: 0) {
                Text("REST").font(.caption2.weight(.bold)).tracking(1).foregroundStyle(DS.Palette.rest)
                Text(restTimeString)
                    .font(.title3.weight(.bold)).monospacedDigit()
                    .contentTransition(.numericText())
            }
            Spacer()
            Button { extendRest(15) } label: {
                Text("+15s").font(.subheadline.weight(.bold)).foregroundStyle(DS.Palette.rest)
                    .padding(.horizontal, DS.Spacing.md).padding(.vertical, DS.Spacing.sm)
                    .background(DS.Palette.rest.opacity(0.16), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add 15 seconds")
            Button { skipRest() } label: {
                Text("Skip").font(.subheadline.weight(.bold)).foregroundStyle(.white)
                    .padding(.horizontal, DS.Spacing.lg).padding(.vertical, DS.Spacing.sm)
                    .background(DS.Palette.rest, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip rest and continue")
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .background(.regularMaterial)
        .overlay(Rectangle().fill(DS.Palette.rest.opacity(0.25)).frame(height: 1), alignment: .top)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Resting, \(restTimeString) remaining")
    }

    private var restTimerToggle: some View {
        Button {
            startRest()
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
        startRest()
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
                        Text(exercise.machineName)
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
                    Button(role: .destructive, action: onRemoveExercise) {
                        Image(systemName: "trash")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                    }
                    .accessibilityLabel("Remove \(exercise.machineName) from session")
                }

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
