import SwiftUI
import SwiftData

// MARK: - Plans list

/// Lists the user's saved training plans, lets one be marked "active" (the plan
/// the NFC scan flow loads targets from), and opens the builder.
struct PlansListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutPlan.sortIndex) private var plans: [WorkoutPlan]
    @AppStorage("active.plan.id") private var activePlanID: String = ""

    @State private var creating = false
    @State private var editingPlan: WorkoutPlan?

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                if plans.isEmpty {
                    EmptyStateView(
                        icon: "list.bullet.rectangle.portrait.fill",
                        title: "No plans yet",
                        message: "Build a plan from your machines — then just scan a machine to jump straight into it.",
                        actionTitle: "Create Plan"
                    ) { creating = true }
                    .padding(.top, DS.Spacing.xl)
                } else {
                    ForEach(plans) { plan in
                        planRow(plan)
                    }
                    NavigationLink { PlanGeneratorView() } label: {
                        Label("Suggest a plan with AI", systemImage: "wand.and.stars")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.Palette.accentSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.md)
                            .background(DS.Palette.accentSecondary.opacity(0.10), in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.xl)
        }
        .background(GymBackground().ignoresSafeArea())
        .navigationTitle("Training Plans")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { creating = true } label: { Image(systemName: "plus").fontWeight(.semibold) }
                    .accessibilityLabel("New plan")
            }
        }
        .sheet(isPresented: $creating) { PlanBuilderView() }
        .sheet(item: $editingPlan) { PlanBuilderView(plan: $0) }
    }

    private func isActive(_ plan: WorkoutPlan) -> Bool { plan.id.uuidString == activePlanID }

    private func planRow(_ plan: WorkoutPlan) -> some View {
        SurfaceCard {
            HStack(spacing: DS.Spacing.md) {
                Button {
                    activePlanID = isActive(plan) ? "" : plan.id.uuidString
                } label: {
                    Image(systemName: isActive(plan) ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isActive(plan) ? DS.Palette.success : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isActive(plan) ? "Active plan" : "Set as active plan")

                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.name).font(.headline.weight(.bold))
                    Text("\(plan.exercises.count) machine\(plan.exercises.count == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { editingPlan = plan } label: {
                    Image(systemName: "slider.horizontal.3").foregroundStyle(DS.Palette.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit \(plan.name)")
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                if isActive(plan) { activePlanID = "" }
                modelContext.delete(plan)
                try? modelContext.save()
            } label: { Label("Delete Plan", systemImage: "trash") }
        }
    }
}

// MARK: - Plan builder

/// Create or edit a plan: name it, add machines from the active gym, and set
/// each machine's target sets / reps / weight.
struct PlanBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(GymSelection.self) private var gymSelection
    @Query private var gyms: [Gym]

    private let editing: WorkoutPlan?
    init(plan: WorkoutPlan? = nil) { self.editing = plan }

    @State private var name = ""
    @State private var items: [Draft] = []
    @State private var showingPicker = false

    struct Draft: Identifiable {
        let id = UUID()
        let machineID: UUID
        let machineName: String
        let machineCode: String?
        var sets: Int
        var reps: Int
        var weight: Double
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("Plan name (e.g. Push Day)", text: $name) }

                Section("Machines") {
                    ForEach($items) { $item in
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Text(item.machineName).font(.body.weight(.semibold))
                            Stepper("Sets \(item.sets)", value: $item.sets, in: 1...12)
                                .font(.caption)
                            Stepper("Reps \(item.reps)", value: $item.reps, in: 1...50)
                                .font(.caption)
                            Stepper("Weight \(weightText(item.weight)) kg", value: $item.weight, in: 0...500, step: 2.5)
                                .font(.caption)
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { items.remove(atOffsets: $0) }
                    .onMove { items.move(fromOffsets: $0, toOffset: $1) }

                    Button { showingPicker = true } label: {
                        Label("Add machines", systemImage: "plus.circle.fill")
                            .foregroundStyle(DS.Palette.accent)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(DS.Palette.background.ignoresSafeArea())
            .navigationTitle(editing == nil ? "New Plan" : "Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || items.isEmpty)
                }
                ToolbarItem(placement: .topBarLeading) { EditButton() }
            }
            .sheet(isPresented: $showingPicker) { machinePicker }
            .task { loadIfEditing() }
        }
    }

    private var activeGym: Gym? { gymSelection.activeGym(from: gyms) }

    private var availableMachines: [Machine] {
        (activeGym?.sortedAreas ?? []).flatMap { $0.sortedMachines }
            .filter { machine in !items.contains { $0.machineID == machine.id } }
    }

    private var machinePicker: some View {
        NavigationStack {
            List(availableMachines) { machine in
                Button {
                    let suggestion = CoachService(context: modelContext).nextSet(forMachineID: machine.id, goal: .muscleGain)
                    items.append(Draft(
                        machineID: machine.id,
                        machineName: machine.name,
                        machineCode: machine.machineCode,
                        sets: max(suggestion.sets, 1),
                        reps: suggestion.reps,
                        weight: suggestion.weight > 0 ? suggestion.weight : 20
                    ))
                } label: {
                    HStack {
                        Text(machine.name)
                        Spacer()
                        Image(systemName: "plus.circle").foregroundStyle(DS.Palette.accent)
                    }
                }
            }
            .navigationTitle("Add Machines")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if availableMachines.isEmpty {
                    EmptyStateView(icon: "dumbbell.fill", title: "All added",
                                   message: "Every machine in this gym is already in the plan.")
                }
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingPicker = false } } }
        }
    }

    private func weightText(_ w: Double) -> String {
        w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w)
    }

    private func loadIfEditing() {
        guard let editing, items.isEmpty, name.isEmpty else { return }
        name = editing.name
        items = editing.sortedExercises.map {
            Draft(machineID: $0.machineID, machineName: $0.machineName, machineCode: $0.machineCode,
                  sets: $0.targetSets, reps: $0.targetReps, weight: $0.targetWeight)
        }
    }

    private func save() {
        let plan: WorkoutPlan
        if let editing {
            plan = editing
            for ex in editing.exercises { modelContext.delete(ex) }
            plan.exercises = []
        } else {
            let count = (try? modelContext.fetchCount(FetchDescriptor<WorkoutPlan>())) ?? 0
            plan = WorkoutPlan(name: name.trimmingCharacters(in: .whitespaces), sortIndex: count)
            modelContext.insert(plan)
        }
        plan.name = name.trimmingCharacters(in: .whitespaces)
        plan.exercises = items.enumerated().map { idx, draft in
            PlanExercise(machineID: draft.machineID, machineName: draft.machineName, machineCode: draft.machineCode,
                         targetSets: draft.sets, targetReps: draft.reps, targetWeight: draft.weight, sortIndex: idx)
        }
        try? modelContext.save()
        dismiss()
    }
}
