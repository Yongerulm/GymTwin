import Foundation

/// Inputs for a natural-language coaching line. Pure value type so the
/// template narrator is trivially testable and the LLM narrator is a drop-in.
struct CoachingContext: Sendable {
    var readiness: Int
    var readinessTitle: String
    var workoutsThisWeek: Int
    var weeklyGoal: Int
    var streakDays: Int
    var topReadyMuscle: String?
    var goal: TrainingGoal

    init(
        readiness: Int,
        readinessTitle: String,
        workoutsThisWeek: Int,
        weeklyGoal: Int,
        streakDays: Int,
        topReadyMuscle: String?,
        goal: TrainingGoal
    ) {
        self.readiness = readiness
        self.readinessTitle = readinessTitle
        self.workoutsThisWeek = workoutsThisWeek
        self.weeklyGoal = weeklyGoal
        self.streakDays = streakDays
        self.topReadyMuscle = topReadyMuscle
        self.goal = goal
    }
}

/// The text-coaching seam. Distinct from `AIWorkoutCoach` (which prescribes
/// safety-critical numbers deterministically): this produces calm, natural
/// coaching copy that the on-device Apple Intelligence model can generate,
/// with a deterministic template fallback that is always available.
protocol CoachNarrator: Sendable {
    /// A short, calm coaching line (1–2 sentences) for the dashboard.
    func dailyInsight(_ context: CoachingContext) async -> String
}

/// Deterministic, always-available coaching copy. No AI — used as the default
/// and as the fallback whenever an on-device model is unavailable or errors.
struct TemplateCoachNarrator: CoachNarrator {
    func dailyInsight(_ context: CoachingContext) async -> String {
        var lines: [String] = []

        switch context.readiness {
        case ..<40:
            lines.append("Recovery is low today — keep it light or focus on mobility.")
        case 40..<60:
            lines.append("You're partly recovered; train at a moderate intensity and leave a rep in reserve.")
        case 60..<80:
            lines.append("You're recovered and ready — train as planned and chase your targets.")
        default:
            lines.append("Peak recovery — a strong day to push for a personal record.")
        }

        let remaining = max(0, context.weeklyGoal - context.workoutsThisWeek)
        if remaining == 0 {
            lines.append("You've hit your \(context.weeklyGoal)-session goal this week — excellent consistency.")
        } else {
            lines.append("\(remaining) more session\(remaining == 1 ? "" : "s") to reach your weekly goal.")
        }

        if let muscle = context.topReadyMuscle {
            lines.append("\(muscle) is fully recovered, a good focus for today.")
        }

        return lines.joined(separator: " ")
    }
}

/// Selects the best available narrator: the on-device Apple Intelligence model
/// when the device supports it, otherwise the deterministic template.
enum CoachNarratorProvider {
    static func make() -> CoachNarrator {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), FoundationModelsCoachNarrator.isAvailable {
            return FoundationModelsCoachNarrator()
        }
        #endif
        return TemplateCoachNarrator()
    }
}
