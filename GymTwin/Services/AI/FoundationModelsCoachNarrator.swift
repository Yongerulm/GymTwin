#if canImport(FoundationModels)
import FoundationModels
import Foundation

/// On-device Apple Intelligence narrator. Runs Apple's `SystemLanguageModel`
/// locally (no network, no data leaves the device) to phrase the daily
/// coaching line. Falls back to the deterministic template on any error or
/// when the model is unavailable — so the app never depends on it.
@available(iOS 26.0, *)
struct FoundationModelsCoachNarrator: CoachNarrator {

    /// Whether the on-device model is ready (capable device, enabled, not busy).
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    func dailyInsight(_ context: CoachingContext) async -> String {
        let fallback = TemplateCoachNarrator()

        let instructions = """
        You are a calm, expert strength coach inside a fitness app. \
        Reply with at most two short sentences of specific, encouraging advice. \
        Never use hype, emojis, or exclamation marks.
        """

        var prompt = """
        Today's training data:
        - Readiness: \(context.readiness)/100 (\(context.readinessTitle))
        - Sessions this week: \(context.workoutsThisWeek) of \(context.weeklyGoal)
        - Current streak: \(context.streakDays) days
        - Goal: \(context.goal.rawValue)
        """
        if let muscle = context.topReadyMuscle {
            prompt += "\n- Most recovered muscle: \(muscle)"
        }
        prompt += "\nGive one piece of coaching for today."

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? await fallback.dailyInsight(context) : text
        } catch {
            return await fallback.dailyInsight(context)
        }
    }
}
#endif
