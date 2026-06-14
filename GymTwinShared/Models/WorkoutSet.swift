import Foundation
import SwiftData

/// The kind of a logged set. Drives display tags and (later) analytics that
/// treat e.g. warm-ups differently from working sets.
enum WorkoutSetType: String, Codable, CaseIterable, Sendable {
    case warmup, working, dropset, amrap, superset, emom, tabata, circuit, timed, cluster

    /// Full display name.
    var label: String {
        switch self {
        case .warmup: return "Warm-up"
        case .working: return "Working"
        case .dropset: return "Drop Set"
        case .amrap: return "AMRAP"
        case .superset: return "Superset"
        case .emom: return "EMOM"
        case .tabata: return "Tabata"
        case .circuit: return "Circuit"
        case .timed: return "Timed"
        case .cluster: return "Cluster"
        }
    }

    /// Short tag shown on a logged-set row (nil for ordinary working sets).
    var tag: String? {
        switch self {
        case .working: return nil
        case .warmup: return "Warm-up"
        case .dropset: return "Drop"
        case .amrap: return "AMRAP"
        case .superset: return "Super"
        case .emom: return "EMOM"
        case .tabata: return "Tabata"
        case .circuit: return "Circuit"
        case .timed: return "Timed"
        case .cluster: return "Cluster"
        }
    }

    /// Whether this set counts as a normal working effort (vs warm-up).
    var countsAsWorking: Bool { self != .warmup }
}

/// A single set: a weight lifted for a number of repetitions, e.g. 55 kg × 12.
@Model
final class WorkoutSet {
    @Attribute(.unique) var id: UUID
    /// Weight in kilograms.
    var weight: Double
    var repetitions: Int
    var timestamp: Date
    var sortIndex: Int
    /// Raw value of the set's `WorkoutSetType` (defaults to working).
    /// Inline default keeps existing stores lightweight-migratable.
    var typeRaw: String = WorkoutSetType.working.rawValue

    /// Owning exercise. Plain back-reference; cascade lives on `WorkoutExercise.sets`.
    var exercise: WorkoutExercise?

    init(
        id: UUID = UUID(),
        weight: Double,
        repetitions: Int,
        timestamp: Date = Date(),
        sortIndex: Int = 0,
        type: WorkoutSetType = .working
    ) {
        self.id = id
        self.weight = weight
        self.repetitions = repetitions
        self.timestamp = timestamp
        self.sortIndex = sortIndex
        self.typeRaw = type.rawValue
    }

    /// Typed accessor for the set kind.
    var type: WorkoutSetType {
        get { WorkoutSetType(rawValue: typeRaw) ?? .working }
        set { typeRaw = newValue.rawValue }
    }

    /// Volume contributed by this set (weight × reps).
    var volume: Double {
        weight * Double(repetitions)
    }
}
