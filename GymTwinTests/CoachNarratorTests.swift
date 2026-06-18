import XCTest
@testable import GymTwin

/// Unit tests for `TemplateCoachNarrator` — the deterministic, always-available
/// coaching copy used as the default and the on-device-model fallback.
final class CoachNarratorTests: XCTestCase {

    private let narrator = TemplateCoachNarrator()

    private func context(
        readiness: Int = 70,
        workoutsThisWeek: Int = 2,
        weeklyGoal: Int = 5,
        streakDays: Int = 3,
        topReadyMuscle: String? = nil
    ) -> CoachingContext {
        CoachingContext(
            readiness: readiness,
            readinessTitle: "Ready",
            workoutsThisWeek: workoutsThisWeek,
            weeklyGoal: weeklyGoal,
            streakDays: streakDays,
            topReadyMuscle: topReadyMuscle,
            goal: .muscleGain
        )
    }

    func testLowReadiness_advisesRest() async {
        let line = await narrator.dailyInsight(context(readiness: 20))
        XCTAssertTrue(line.localizedCaseInsensitiveContains("light")
                      || line.localizedCaseInsensitiveContains("mobility"),
                      "Low readiness should advise a lighter day. Got: \(line)")
    }

    func testPeakReadiness_encouragesPR() async {
        let line = await narrator.dailyInsight(context(readiness: 95))
        XCTAssertTrue(line.localizedCaseInsensitiveContains("personal record")
                      || line.localizedCaseInsensitiveContains("peak"),
                      "Peak readiness should encourage a PR. Got: \(line)")
    }

    func testWeeklyGoalMet_mentionsConsistency() async {
        let line = await narrator.dailyInsight(context(workoutsThisWeek: 5, weeklyGoal: 5))
        XCTAssertTrue(line.localizedCaseInsensitiveContains("goal"),
                      "Hitting the goal should be acknowledged. Got: \(line)")
    }

    func testRemainingSessions_isPluralisedCorrectly() async {
        let one = await narrator.dailyInsight(context(workoutsThisWeek: 4, weeklyGoal: 5))
        XCTAssertTrue(one.contains("1 more session"), "Expected singular phrasing. Got: \(one)")

        let many = await narrator.dailyInsight(context(workoutsThisWeek: 2, weeklyGoal: 5))
        XCTAssertTrue(many.contains("3 more sessions"), "Expected plural phrasing. Got: \(many)")
    }

    func testTopReadyMuscle_isSuggestedWhenPresent() async {
        let line = await narrator.dailyInsight(context(topReadyMuscle: "Chest"))
        XCTAssertTrue(line.contains("Chest"), "A recovered muscle should be suggested. Got: \(line)")
    }

    func testNoMuscle_omitsSuggestion() async {
        let line = await narrator.dailyInsight(context(topReadyMuscle: nil))
        XCTAssertFalse(line.localizedCaseInsensitiveContains("recovered, a good focus"),
                       "No muscle should mean no focus suggestion. Got: \(line)")
    }
}
