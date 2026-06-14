import Foundation

// MARK: - Inputs

/// One past performance data point for a machine, oldest-to-newest when in an
/// array. The coach reasons purely over these, so it is trivially testable and
/// works fully offline.
struct PerformanceSample: Hashable, Sendable {
    let weight: Double
    let reps: Int
    let sets: Int
    let date: Date
    var rpe: Double?

    init(weight: Double, reps: Int, sets: Int = 1, date: Date, rpe: Double? = nil) {
        self.weight = weight
        self.reps = reps
        self.sets = sets
        self.date = date
        self.rpe = rpe
    }
}

enum TrainingGoal: String, CaseIterable, Codable, Sendable {
    case muscleGain = "Muscle Gain"
    case strength = "Strength"
    case endurance = "Endurance"
    case fatLoss = "Fat Loss"

    /// Target rep range used for recommendations under this goal.
    var targetReps: Int {
        switch self {
        case .muscleGain: return 10
        case .strength: return 5
        case .endurance: return 15
        case .fatLoss: return 12
        }
    }

    var setCount: Int {
        switch self {
        case .strength: return 5
        case .muscleGain: return 4
        case .fatLoss, .endurance: return 3
        }
    }
}

enum PlanSplit: String, CaseIterable, Codable, Sendable {
    case fullBody = "Full Body"
    case upperLower = "Upper / Lower"
    case pushPullLegs = "Push / Pull / Legs"
}

// MARK: - Outputs

/// A single weight recommendation with a human, calm explanation.
struct WeightRecommendation: Hashable, Sendable {
    let recommendedWeight: Double
    /// Delta vs the previous weight (can be negative for a deload).
    let change: Double
    let reason: String
}

/// A complete next-set prescription.
struct SetRecommendation: Hashable, Sendable {
    let weight: Double
    let reps: Int
    let sets: Int
    var note: String?
}

/// What the progression engine advises after evaluating history.
enum ProgressionAction: String, Hashable, Sendable {
    case increaseLoad
    case maintain
    case deload
}

struct ProgressionAdvice: Hashable, Sendable {
    let action: ProgressionAction
    let suggestedWeight: Double
    let message: String
}

/// Whether a deload is warranted, and why.
struct DeloadSignal: Hashable, Sendable {
    let isRecommended: Bool
    let reason: String
    /// 0 = none, 1 = mild, 2 = strong.
    let severity: Int

    static let none = DeloadSignal(isRecommended: false, reason: "Performance is trending well.", severity: 0)
}

/// A generated training plan.
struct TrainingPlan: Identifiable, Hashable, Sendable {
    let id: UUID
    let goal: TrainingGoal
    let daysPerWeek: Int
    let split: PlanSplit
    let days: [PlanDay]

    init(id: UUID = UUID(), goal: TrainingGoal, daysPerWeek: Int, split: PlanSplit, days: [PlanDay]) {
        self.id = id
        self.goal = goal
        self.daysPerWeek = daysPerWeek
        self.split = split
        self.days = days
    }
}

struct PlanDay: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let focus: String
    /// Machine codes prescribed for this day, in order.
    let machineCodes: [String]

    init(id: UUID = UUID(), title: String, focus: String, machineCodes: [String]) {
        self.id = id
        self.title = title
        self.focus = focus
        self.machineCodes = machineCodes
    }
}

// MARK: - Coach protocol

/// The training-intelligence seam. The app depends only on this protocol, so
/// the deterministic on-device engine can later be swapped for / augmented by
/// Apple Foundation Models or a cloud LLM without touching call sites.
protocol AIWorkoutCoach: Sendable {
    /// Suggest the next working weight from the last set.
    func recommendWeight(lastWeight: Double, lastReps: Int, targetReps: Int) -> WeightRecommendation

    /// Prescribe the next set from full history for a machine.
    func nextSet(history: [PerformanceSample], goal: TrainingGoal) -> SetRecommendation

    /// Evaluate progressive-overload state from history.
    func evaluateProgression(history: [PerformanceSample], targetReps: Int) -> ProgressionAdvice

    /// Detect stagnation / regression / overtraining warranting a deload.
    func detectDeload(history: [PerformanceSample]) -> DeloadSignal

    /// Generate a split training plan from a goal and weekly frequency.
    func generatePlan(goal: TrainingGoal, daysPerWeek: Int, available: [MachineDefinition]) -> TrainingPlan
}

/// Shared numeric helpers for plate-based rounding.
enum Loading {
    /// Smallest sensible increment on a selectorized stack / with micro-plates.
    static let increment: Double = 2.5

    static func round(_ weight: Double) -> Double {
        (weight / increment).rounded() * increment
    }
}
