import XCTest
@testable import GymTwin

/// Unit tests for `DeterministicWorkoutCoach` — weight recommendations,
/// progression evaluation, deload detection, and plan generation.
///
/// The coach is a pure value type that operates on `PerformanceSample` arrays,
/// so no SwiftData context or mocking is required.
final class AICoachTests: XCTestCase {

    private let coach = DeterministicWorkoutCoach()

    // MARK: - recommendWeight

    func testRecommendWeight_hitTarget_incrementsBySmallestPlate() {
        // Arrange
        let lastWeight = 40.0
        let lastReps = 12
        let targetReps = 12

        // Act
        let result = coach.recommendWeight(lastWeight: lastWeight, lastReps: lastReps, targetReps: targetReps)

        // Assert — hit the target, so weight should increase by 2.5 kg
        XCTAssertEqual(result.recommendedWeight, 42.5,
                       "Hitting the target rep count should add the 2.5 kg minimum increment.")
    }

    func testRecommendWeight_fellShort_returnsWeightAtOrBelowPrevious() {
        // Arrange — 6 reps when targeting 12 is well short (>= 3 gap)
        let lastWeight = 40.0
        let lastReps = 6
        let targetReps = 12

        // Act
        let result = coach.recommendWeight(lastWeight: lastWeight, lastReps: lastReps, targetReps: targetReps)

        // Assert — fell well short, so weight must not increase
        XCTAssertLessThanOrEqual(result.recommendedWeight, lastWeight,
                                  "Falling short of target by 6 reps should reduce or hold the weight.")
    }

    func testRecommendWeight_closeToTarget_holdsCurrentWeight() {
        // Arrange — 11 reps when targeting 12 is within 1 rep (close case)
        let lastWeight = 40.0
        let lastReps = 11
        let targetReps = 12

        // Act
        let result = coach.recommendWeight(lastWeight: lastWeight, lastReps: lastReps, targetReps: targetReps)

        // Assert — close but not there; hold at current weight
        XCTAssertEqual(result.recommendedWeight, lastWeight,
                       "Being one rep short should keep the weight unchanged.")
    }

    // MARK: - evaluateProgression

    func testEvaluateProgression_twoOnTargetSessions_advancesLoad() {
        // Arrange — two consecutive sessions at 40 kg, both hitting the 12-rep target
        let targetReps = 12
        let history: [PerformanceSample] = [
            PerformanceSample(weight: 40.0, reps: 12, sets: 3, date: Date(timeIntervalSinceNow: -86400 * 7)),
            PerformanceSample(weight: 40.0, reps: 12, sets: 3, date: Date(timeIntervalSinceNow: -86400 * 3)),
        ]

        // Act
        let advice = coach.evaluateProgression(history: history, targetReps: targetReps)

        // Assert — two on-target sessions at the same weight should trigger a load increase to 42.5 kg
        XCTAssertEqual(advice.action, .increaseLoad,
                       "Two consecutive on-target sessions should recommend increasing load.")
        XCTAssertEqual(advice.suggestedWeight, 42.5,
                       "Suggested weight should be 40 + 2.5 = 42.5 kg.")
    }

    // MARK: - detectDeload

    func testDetectDeload_threeStrictlyDecreasingWeights_recommendsDeload() {
        // Arrange — three sessions with weights dropping each time: 45 → 42.5 → 40
        let history: [PerformanceSample] = [
            PerformanceSample(weight: 45.0, reps: 10, sets: 3, date: Date(timeIntervalSinceNow: -86400 * 14)),
            PerformanceSample(weight: 42.5, reps: 10, sets: 3, date: Date(timeIntervalSinceNow: -86400 * 7)),
            PerformanceSample(weight: 40.0, reps: 10, sets: 3, date: Date(timeIntervalSinceNow: -86400)),
        ]

        // Act
        let signal = coach.detectDeload(history: history)

        // Assert — strictly decreasing weights across three sessions signal fatigue
        XCTAssertTrue(signal.isRecommended,
                      "Three strictly-decreasing weight sessions should trigger a deload recommendation.")
    }

    func testDetectDeload_insufficientHistory_noDeloadSignal() {
        // Arrange — fewer than 3 sessions is insufficient for trend detection
        let history: [PerformanceSample] = [
            PerformanceSample(weight: 50.0, reps: 10, sets: 3, date: Date(timeIntervalSinceNow: -86400)),
            PerformanceSample(weight: 45.0, reps: 10, sets: 3, date: Date()),
        ]

        // Act
        let signal = coach.detectDeload(history: history)

        // Assert
        XCTAssertFalse(signal.isRecommended,
                       "Two sessions should not be enough to trigger a deload.")
    }

    // MARK: - generatePlan

    func testGeneratePlan_muscleGain3Days_pushPullLegsSplit3Days() {
        // Arrange — machines covering push, pull, and legs categories
        let available: [MachineDefinition] = [
            MachineDefinition(machineCode: "sscp", name: "Chest Press", category: "Push"),
            MachineDefinition(machineCode: "ssfly", name: "Pectoral Fly", category: "Push"),
            MachineDefinition(machineCode: "sspd",  name: "Pulldown", category: "Pull"),
            MachineDefinition(machineCode: "ssbc",  name: "Biceps Curl", category: "Pull"),
            MachineDefinition(machineCode: "ssle",  name: "Leg Extension", category: "Legs"),
            MachineDefinition(machineCode: "ssab",  name: "Abdominal", category: "Core"),
        ]

        // Act
        let plan = coach.generatePlan(goal: .muscleGain, daysPerWeek: 3, available: available)

        // Assert — 3 days + muscle-gain goal → Push / Pull / Legs split
        XCTAssertEqual(plan.split, .pushPullLegs,
                       "Muscle-gain at 3 days per week should use a Push/Pull/Legs split.")
        XCTAssertEqual(plan.days.count, 3,
                       "The generated plan should have exactly 3 training days.")
    }
}
