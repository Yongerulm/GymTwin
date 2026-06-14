import Foundation

/// On-device, fully deterministic training intelligence. Implements the
/// product's progression rules with no network and no API keys, so the AI
/// experience works offline today. It is the default `AIWorkoutCoach`; a
/// Foundation Models / cloud coach can later wrap or replace it behind the
/// same protocol.
struct DeterministicWorkoutCoach: AIWorkoutCoach {

    /// Consecutive on-target sessions required before adding load.
    private let sessionsToProgress = 2

    // MARK: - Weight recommendation

    func recommendWeight(lastWeight: Double, lastReps: Int, targetReps: Int) -> WeightRecommendation {
        guard lastWeight > 0 else {
            return WeightRecommendation(recommendedWeight: 0, change: 0, reason: "Log a set to calibrate your first recommendation.")
        }
        // Hit (or beat) the target → add the smallest increment.
        if lastReps >= targetReps {
            let next = Loading.round(lastWeight + Loading.increment)
            return WeightRecommendation(
                recommendedWeight: next,
                change: next - lastWeight,
                reason: "You hit \(lastReps) reps — add \(format(Loading.increment)) kg and keep progressing."
            )
        }
        // Fell well short → reduce slightly to rebuild quality reps.
        if lastReps <= targetReps - 3 {
            let next = Loading.round(lastWeight - Loading.increment)
            return WeightRecommendation(
                recommendedWeight: max(next, Loading.increment),
                change: next - lastWeight,
                reason: "Last set fell short of \(targetReps) reps — ease back to rebuild clean reps."
            )
        }
        // Close to target → hold and earn the reps.
        return WeightRecommendation(
            recommendedWeight: lastWeight,
            change: 0,
            reason: "Stay at \(format(lastWeight)) kg until you reach \(targetReps) reps."
        )
    }

    // MARK: - Next set

    func nextSet(history: [PerformanceSample], goal: TrainingGoal) -> SetRecommendation {
        guard let last = history.last else {
            return SetRecommendation(weight: 0, reps: goal.targetReps, sets: goal.setCount,
                                     note: "First session — pick a weight you can control for \(goal.targetReps) reps.")
        }
        let rec = recommendWeight(lastWeight: last.weight, lastReps: last.reps, targetReps: goal.targetReps)
        let deload = detectDeload(history: history)
        if deload.isRecommended {
            let lighter = Loading.round(last.weight * 0.9)
            return SetRecommendation(weight: lighter, reps: goal.targetReps, sets: max(goal.setCount - 1, 2),
                                     note: deload.reason)
        }
        return SetRecommendation(weight: rec.recommendedWeight, reps: goal.targetReps, sets: goal.setCount,
                                 note: rec.reason)
    }

    // MARK: - Progression

    func evaluateProgression(history: [PerformanceSample], targetReps: Int) -> ProgressionAdvice {
        guard let last = history.last else {
            return ProgressionAdvice(action: .maintain, suggestedWeight: 0, message: "No history yet.")
        }
        let deload = detectDeload(history: history)
        if deload.isRecommended {
            let lighter = Loading.round(last.weight * 0.9)
            return ProgressionAdvice(action: .deload, suggestedWeight: lighter, message: deload.reason)
        }
        // Count trailing consecutive on-target sessions at the current weight.
        let onTargetStreak = trailingOnTargetStreak(history: history, targetReps: targetReps)
        if onTargetStreak >= sessionsToProgress {
            let next = Loading.round(last.weight + Loading.increment)
            return ProgressionAdvice(
                action: .increaseLoad,
                suggestedWeight: next,
                message: "\(onTargetStreak) strong sessions — time to add \(format(Loading.increment)) kg."
            )
        }
        return ProgressionAdvice(
            action: .maintain,
            suggestedWeight: last.weight,
            message: "Keep building reps at \(format(last.weight)) kg (\(onTargetStreak)/\(sessionsToProgress) on target)."
        )
    }

    // MARK: - Deload detection

    func detectDeload(history: [PerformanceSample]) -> DeloadSignal {
        // Need a few sessions to judge a trend.
        guard history.count >= 3 else { return .none }
        let recent = Array(history.suffix(3))

        // Regression: top weight strictly decreasing across the last 3 sessions.
        if recent[0].weight > recent[1].weight, recent[1].weight > recent[2].weight {
            return DeloadSignal(isRecommended: true,
                                reason: "Weight has dropped three sessions in a row — take a lighter recovery day.",
                                severity: 2)
        }
        // Stagnation: identical weight for 3+ sessions and reps not improving.
        let sameWeight = recent.allSatisfy { abs($0.weight - recent[0].weight) < 0.01 }
        let repsNotImproving = recent[2].reps <= recent[0].reps
        if sameWeight, repsNotImproving {
            return DeloadSignal(isRecommended: true,
                                reason: "Progress has stalled — a 10% deload often breaks a plateau.",
                                severity: 1)
        }
        // Overtraining proxy: rising RPE with flat or falling reps.
        if let r0 = recent[0].rpe, let r2 = recent[2].rpe, r2 >= r0 + 1, recent[2].reps <= recent[0].reps {
            return DeloadSignal(isRecommended: true,
                                reason: "Effort is climbing while reps aren't — ease off to recover.",
                                severity: 1)
        }
        return .none
    }

    // MARK: - Plan generator

    func generatePlan(goal: TrainingGoal, daysPerWeek: Int, available: [MachineDefinition]) -> TrainingPlan {
        let clampedDays = min(max(daysPerWeek, 1), 6)
        let split: PlanSplit = {
            switch clampedDays {
            case ...2: return .fullBody
            case 3: return goal == .strength ? .fullBody : .pushPullLegs
            case 4: return .upperLower
            default: return .pushPullLegs
            }
        }()

        let byCategory = Dictionary(grouping: available) { $0.category.lowercased() }
        func codes(_ categories: [String], limit: Int = 5) -> [String] {
            categories.flatMap { byCategory[$0] ?? [] }.map(\.machineCode).prefix(limit).map { $0 }
        }
        let push = codes(["push"]); let pull = codes(["pull"]); let legs = codes(["legs"]); let core = codes(["core"])
        let all = available.map(\.machineCode)

        let days: [PlanDay]
        switch split {
        case .fullBody:
            days = (1...clampedDays).map { i in
                PlanDay(title: "Day \(i) · Full Body", focus: "Whole body", machineCodes: Array(all.prefix(6)))
            }
        case .upperLower:
            days = (1...clampedDays).map { i in
                i.isMultiple(of: 2)
                    ? PlanDay(title: "Day \(i) · Lower", focus: "Legs & Core", machineCodes: legs + core)
                    : PlanDay(title: "Day \(i) · Upper", focus: "Chest, Back & Arms", machineCodes: push + pull)
            }
        case .pushPullLegs:
            let rotation = [
                PlanDay(title: "Push", focus: "Chest, Shoulders, Triceps", machineCodes: push),
                PlanDay(title: "Pull", focus: "Back & Biceps", machineCodes: pull),
                PlanDay(title: "Legs", focus: "Quads, Hamstrings, Core", machineCodes: legs + core),
            ]
            days = (0..<clampedDays).map { i in
                let base = rotation[i % rotation.count]
                return PlanDay(title: "Day \(i + 1) · \(base.title)", focus: base.focus, machineCodes: base.machineCodes)
            }
        }
        return TrainingPlan(goal: goal, daysPerWeek: clampedDays, split: split, days: days)
    }

    // MARK: - Helpers

    private func trailingOnTargetStreak(history: [PerformanceSample], targetReps: Int) -> Int {
        guard let currentWeight = history.last?.weight else { return 0 }
        var streak = 0
        for sample in history.reversed() {
            guard abs(sample.weight - currentWeight) < 0.01 else { break }
            if sample.reps >= targetReps { streak += 1 } else { break }
        }
        return streak
    }

    private func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}
