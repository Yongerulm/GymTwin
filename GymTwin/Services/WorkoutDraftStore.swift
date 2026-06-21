import Foundation

/// A persisted snapshot of an in-progress workout so it survives the app being
/// closed or killed mid-session. Stored as JSON in the App Group; written on
/// every change and cleared when the session is finished or discarded.
struct WorkoutDraft: Codable, Sendable {
    var startDate: Date
    var exercises: [Exercise]

    struct Exercise: Codable, Sendable {
        var machineID: UUID
        var machineName: String
        var planExerciseID: UUID?
        var targetSets: Int?
        var targetReps: Int?
        var targetWeight: Double?
        var sets: [LoggedSet]
    }

    struct LoggedSet: Codable, Sendable {
        var weight: Double
        var reps: Int
        var typeRaw: String
    }

    /// Total sets logged so far, for the resume summary.
    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets.count } }
    /// Whether there's anything worth resuming (at least one exercise).
    var isResumable: Bool { !exercises.isEmpty }
}

/// Reads/writes the in-progress workout draft in the shared App Group.
enum WorkoutDraftStore {
    private static let key = "workout.draft.v1"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    }

    static func save(_ draft: WorkoutDraft) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        defaults?.set(data, forKey: key)
    }

    static func load() -> WorkoutDraft? {
        guard let data = defaults?.data(forKey: key),
              let draft = try? JSONDecoder().decode(WorkoutDraft.self, from: data),
              draft.isResumable
        else { return nil }
        return draft
    }

    static func clear() {
        defaults?.removeObject(forKey: key)
    }
}
