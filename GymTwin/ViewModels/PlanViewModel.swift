import Foundation
import SwiftData

/// View model for the AI training-plan generator tab.
/// Loads available machine definitions from the local repository, then delegates
/// plan generation to `CoachService`. Call `bind(_:)` once in `.task`, then
/// `refresh()` on every `onAppear`.
@Observable @MainActor
final class PlanViewModel {

    // MARK: - Inputs

    var goal: TrainingGoal = .muscleGain
    var daysPerWeek: Int = 3
    /// The gym whose machines the plan is built from.
    var selectedGymID: UUID?

    // MARK: - Outputs

    private(set) var plan: TrainingPlan?
    private(set) var machineNames: [String: String] = [:]   // machineCode → display name
    private(set) var isGenerating = false
    private(set) var errorMessage: String?
    /// All gyms, for the gym picker.
    private(set) var gyms: [Gym] = []

    // MARK: - Internal

    private var context: ModelContext?

    // MARK: - Bind / Refresh

    func bind(_ context: ModelContext) {
        self.context = context
        loadGyms()
    }

    func refresh() {
        loadGyms()
    }

    private func loadGyms() {
        guard let context else { return }
        gyms = (try? context.fetch(FetchDescriptor<Gym>(sortBy: [SortDescriptor(\.createdDate)]))) ?? []
        if selectedGymID == nil || !gyms.contains(where: { $0.id == selectedGymID }) {
            selectedGymID = gyms.first?.id
        }
    }

    private func selectedGym() -> Gym? {
        gyms.first { $0.id == selectedGymID } ?? gyms.first
    }

    // MARK: - Generate

    /// Fetches available machine definitions offline and asks `CoachService` to
    /// produce a split plan. Populates `plan` and the `machineNames` lookup for
    /// UI rendering.
    func generate() async {
        guard let context else { return }
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        do {
            // Prefer the selected gym's own machines so the plan fits that gym.
            var defs: [MachineDefinition] = (selectedGym()?.sortedAreas ?? []).flatMap { area in
                area.sortedMachines.map { machine in
                    let category = machine.category.isEmpty ? (machine.area?.name ?? "General") : machine.category
                    return MachineDefinition(
                        machineCode: machine.machineCode ?? machine.id.uuidString,
                        name: machine.name,
                        category: category
                    )
                }
            }
            // Fall back to the offline catalog if the gym has no machines yet.
            if defs.isEmpty {
                defs = try await LocalMachineRepository().allMachines()
            }

            // Build a code → name index so views never need to re-fetch.
            var names: [String: String] = [:]
            for def in defs {
                names[def.machineCode] = def.name
            }
            machineNames = names

            let service = CoachService(context: context)
            let generated = service.generatePlan(
                goal: goal,
                daysPerWeek: min(max(daysPerWeek, 1), 6),
                available: defs
            )
            plan = generated
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    /// Human-readable machine names for a `PlanDay`, falling back to the raw
    /// code when the definition is not cached (should not happen in practice).
    func machineList(for day: PlanDay) -> [String] {
        day.machineCodes.map { machineNames[$0] ?? $0 }
    }

    /// One-sentence coach rationale explaining why this split suits the chosen
    /// goal and weekly frequency.
    var splitRationale: String {
        guard let plan else { return "" }
        switch plan.split {
        case .fullBody:
            switch plan.goal {
            case .strength:
                return "Full-body training lets you practise the competition lifts at high frequency — ideal for building maximum strength in \(plan.daysPerWeek) day\(plan.daysPerWeek == 1 ? "" : "s") per week."
            case .muscleGain:
                return "Full-body sessions hit each muscle multiple times weekly, maximising hypertrophy stimulus across \(plan.daysPerWeek) training day\(plan.daysPerWeek == 1 ? "" : "s")."
            case .endurance:
                return "Full-body circuits keep rest intervals short and heart rate elevated — well-suited to \(plan.daysPerWeek)-day endurance training."
            case .fatLoss:
                return "Full-body sessions burn the most calories per visit and are metabolically efficient for fat-loss in \(plan.daysPerWeek) weekly sessions."
            }
        case .upperLower:
            return "Upper / lower splits give each muscle group two dedicated sessions per week while keeping volume manageable — a strong choice for \(plan.goal.rawValue.lowercased()) at \(plan.daysPerWeek) days."
        case .pushPullLegs:
            return "Push / Pull / Legs is the gold standard for \(plan.goal.rawValue.lowercased()): it isolates movement patterns, reduces overlap, and allows high weekly volume across \(plan.daysPerWeek) sessions."
        }
    }
}
