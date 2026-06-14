import Foundation
import SwiftData

/// A user-built training plan: an ordered list of machines with target
/// sets/reps/weight. Distinct from the AI-generated `TrainingPlan` value type —
/// this is persisted and selectable, and drives the NFC scan-into-program flow.
@Model
final class WorkoutPlan {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdDate: Date
    var sortIndex: Int

    @Relationship(deleteRule: .cascade, inverse: \PlanExercise.plan)
    var exercises: [PlanExercise]

    init(id: UUID = UUID(), name: String, createdDate: Date = Date(), sortIndex: Int = 0) {
        self.id = id
        self.name = name
        self.createdDate = createdDate
        self.sortIndex = sortIndex
        self.exercises = []
    }

    var sortedExercises: [PlanExercise] {
        exercises.sorted { $0.sortIndex < $1.sortIndex }
    }

    /// The planned target for a given machine id, if this plan includes it.
    func target(forMachineID machineID: UUID) -> PlanExercise? {
        exercises.first { $0.machineID == machineID }
    }

    /// The planned target matched by scanned machine code, if present.
    func target(forCode code: String) -> PlanExercise? {
        exercises.first { $0.machineCode?.lowercased() == code.lowercased() }
    }
}

/// One planned exercise inside a `WorkoutPlan` — a machine plus its target.
@Model
final class PlanExercise {
    @Attribute(.unique) var id: UUID
    var machineID: UUID
    var machineName: String
    /// Equipment code for NFC/QR matching (mirrors `Machine.machineCode`).
    var machineCode: String?
    var targetSets: Int
    var targetReps: Int
    var targetWeight: Double
    var sortIndex: Int

    var plan: WorkoutPlan?

    init(
        id: UUID = UUID(),
        machineID: UUID,
        machineName: String,
        machineCode: String? = nil,
        targetSets: Int = 3,
        targetReps: Int = 10,
        targetWeight: Double = 20,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.machineID = machineID
        self.machineName = machineName
        self.machineCode = machineCode
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.sortIndex = sortIndex
    }

    /// "55 kg · 3 × 10" style summary.
    var summary: String {
        let w = targetWeight == targetWeight.rounded() ? String(Int(targetWeight)) : String(format: "%.1f", targetWeight)
        return "\(w) kg · \(targetSets) × \(targetReps)"
    }
}
