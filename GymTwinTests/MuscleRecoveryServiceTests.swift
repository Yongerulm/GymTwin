import XCTest
@testable import GymTwin

/// Unit tests for `MuscleRecoveryService` — per-muscle recovery percentage,
/// volume-scaled windows, banding, and area→muscle mapping.
///
/// The service is pure and deterministic (events + a reference `now`), so no
/// SwiftData context or clock mocking is required.
final class MuscleRecoveryServiceTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func hoursAgo(_ h: Double) -> Date {
        now.addingTimeInterval(-h * 3_600)
    }

    // MARK: - statuses

    func testStatuses_untrainedMuscle_isFreshAt100() {
        // Act — no events at all
        let statuses = MuscleRecoveryService.statuses(events: [], now: now)

        // Assert — every tracked group is present and fresh at 100%
        XCTAssertEqual(statuses.count, MuscleRecoveryService.groups.count)
        for status in statuses {
            XCTAssertEqual(status.recoveryPercent, 100)
            XCTAssertEqual(status.band, .fresh)
            XCTAssertNil(status.lastTrained)
        }
    }

    func testStatuses_justTrained_isLowAndRecovering() {
        // Arrange — chest trained right now, light volume
        let events = [MuscleTrainingEvent(muscle: "chest", date: now, volume: 1_000)]

        // Act
        let statuses = MuscleRecoveryService.statuses(events: events, now: now)
        let chest = statuses.first { $0.muscle == "chest" }

        // Assert — 0 hours elapsed => 0%, recovering
        XCTAssertEqual(chest?.recoveryPercent, 0)
        XCTAssertEqual(chest?.band, .recovering)
    }

    func testStatuses_pastWindow_isReadyAt100() {
        // Arrange — chest trained 5 days ago, well beyond any window
        let events = [MuscleTrainingEvent(muscle: "chest", date: hoursAgo(120), volume: 2_000)]

        // Act
        let chest = MuscleRecoveryService.statuses(events: events, now: now).first { $0.muscle == "chest" }

        // Assert
        XCTAssertEqual(chest?.recoveryPercent, 100)
        XCTAssertEqual(chest?.band, .ready)
    }

    func testStatuses_keepsMostRecentSessionPerMuscle() {
        // Arrange — two chest sessions; the recent one should win
        let events = [
            MuscleTrainingEvent(muscle: "chest", date: hoursAgo(100), volume: 500),
            MuscleTrainingEvent(muscle: "chest", date: hoursAgo(2), volume: 500),
        ]

        // Act
        let chest = MuscleRecoveryService.statuses(events: events, now: now).first { $0.muscle == "chest" }

        // Assert — uses the 2h-ago session, so far from fully recovered
        XCTAssertNotNil(chest?.hoursSinceTrained)
        XCTAssertEqual(chest!.hoursSinceTrained!, 2, accuracy: 0.01)
        XCTAssertLessThan(chest!.recoveryPercent, 50)
    }

    func testStatuses_higherVolumeRecoversSlower() {
        // Arrange — same muscle, same elapsed time, different session volumes
        let light = [MuscleTrainingEvent(muscle: "legs", date: hoursAgo(40), volume: 200)]
        let heavy = [MuscleTrainingEvent(muscle: "legs", date: hoursAgo(40), volume: 4_000)]

        // Act
        let lightPct = MuscleRecoveryService.statuses(events: light, now: now).first { $0.muscle == "legs" }!.recoveryPercent
        let heavyPct = MuscleRecoveryService.statuses(events: heavy, now: now).first { $0.muscle == "legs" }!.recoveryPercent

        // Assert — the heavier session has a longer window => lower recovery %
        XCTAssertLessThan(heavyPct, lightPct)
    }

    // MARK: - recoveryWindowHours

    func testRecoveryWindow_scalesWithVolume() {
        let zero = MuscleRecoveryService.recoveryWindowHours(forMuscle: "chest", lastVolume: 0)
        let heavy = MuscleRecoveryService.recoveryWindowHours(forMuscle: "chest", lastVolume: 3_000)

        // Base 48h × 0.85 = 40.8 at zero volume; capped factor 1.30 => 62.4 at/above reference
        XCTAssertEqual(zero, 48 * 0.85, accuracy: 0.001)
        XCTAssertEqual(heavy, 48 * 1.30, accuracy: 0.001)
    }

    // MARK: - canonicalMuscle

    func testCanonicalMuscle_mapsCommonAreas() {
        XCTAssertEqual(MuscleRecoveryService.canonicalMuscle(from: "Chest Press"), "chest")
        XCTAssertEqual(MuscleRecoveryService.canonicalMuscle(from: "Lat Pulldown"), "back")
        XCTAssertEqual(MuscleRecoveryService.canonicalMuscle(from: "Leg Extension"), "legs")
        XCTAssertEqual(MuscleRecoveryService.canonicalMuscle(from: "Shoulder Press"), "shoulders")
        XCTAssertEqual(MuscleRecoveryService.canonicalMuscle(from: "Bicep Curl"), "arms")
        XCTAssertEqual(MuscleRecoveryService.canonicalMuscle(from: "Ab Crunch"), "core")
    }

    func testCanonicalMuscle_returnsNilForNonMuscle() {
        XCTAssertNil(MuscleRecoveryService.canonicalMuscle(from: "Cardio"))
        XCTAssertNil(MuscleRecoveryService.canonicalMuscle(from: "Treadmill"))
    }
}
