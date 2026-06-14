import Foundation

/// Deterministic recovery scoring (0–100).
///
/// The score is composed of three independent components that are summed and
/// clamped. All inputs are optional so the function degrades gracefully when
/// HealthKit data is unavailable.
///
/// ## Heuristic
///
/// | Component       | Weight | Rationale                                       |
/// |-----------------|--------|-------------------------------------------------|
/// | Training load   | 0–50   | Penalises under- or over-training               |
/// | Sleep quality   | 0–30   | 7–9 h is optimal; shorter/longer reduces score |
/// | Resting HR      | 0–20   | Elevated HR signals autonomic stress            |
///
/// ### Training load (0–50)
/// - 2–4 sessions/week in ≤ 45 min avg → 50 pts (ideal)
/// - Each session beyond 4 → –6 pts (overtraining)
/// - 0–1 sessions → 30 pts (detraining / fresh)
/// - Session avg > 75 min → –10 pts additional
///
/// ### Sleep (0–30)
/// - 7–9 h → 30 pts
/// - < 7 h → linear falloff (6 h → 20 pts; 5 h → 10 pts; ≤ 4 h → 0 pts)
/// - > 9 h → slight reduction (10 h → 25 pts; ≥ 11 h → 20 pts, oversleeping)
/// - nil → 20 pts (neutral assumption)
///
/// ### Resting HR (0–20)
/// - ≤ 60 bpm → 20 pts
/// - 61–80 bpm → linear decay to 10 pts
/// - 81–100 bpm → 5 pts
/// - > 100 bpm → 0 pts
/// - nil → 15 pts (neutral assumption)
struct RecoveryService {

    // MARK: - Public API

    /// Returns a recovery score in `0...100`.
    ///
    /// - Parameters:
    ///   - workoutsLast7Days: Number of training sessions in the past 7 days.
    ///   - avgSessionMinutes: Average duration of those sessions in minutes, or `nil` if unknown.
    ///   - sleepHours: Last-night sleep duration in hours, or `nil` if unavailable.
    ///   - restingHR: Most-recent resting heart-rate sample in bpm, or `nil` if unavailable.
    static func score(
        workoutsLast7Days: Int,
        avgSessionMinutes: Double?,
        sleepHours: Double?,
        restingHR: Int?
    ) -> Int {
        let raw = trainingComponent(sessions: workoutsLast7Days, avgMinutes: avgSessionMinutes)
                + sleepComponent(hours: sleepHours)
                + heartRateComponent(bpm: restingHR)
        return max(0, min(100, Int(raw.rounded())))
    }

    // MARK: - Components (internal for testability)

    static func trainingComponent(sessions: Int, avgMinutes: Double?) -> Double {
        // Base load score
        var pts: Double
        switch sessions {
        case 0, 1:
            pts = 30
        case 2, 3, 4:
            pts = 50
        default:
            let excess = sessions - 4
            pts = max(0, 50 - Double(excess) * 6)
        }

        // Penalty for very long average sessions
        if let avg = avgMinutes, avg > 75 {
            pts -= 10
        }

        return max(0, pts)
    }

    static func sleepComponent(hours: Double?) -> Double {
        guard let h = hours else { return 20 } // neutral when unavailable

        switch h {
        case ..<4:
            return 0
        case 4..<7:
            // linear 0→30 over 4–7 h
            let fraction = (h - 4) / 3
            return fraction * 30
        case 7...9:
            return 30
        case 9..<11:
            // slight penalty for oversleeping
            let fraction = (h - 9) / 2
            return 30 - fraction * 10   // 30→20
        default:
            return 20
        }
    }

    static func heartRateComponent(bpm: Int?) -> Double {
        guard let hr = bpm else { return 15 } // neutral when unavailable

        switch hr {
        case ..<61:
            return 20
        case 61..<81:
            // linear 20→10 over 61–80 bpm
            let fraction = Double(hr - 60) / 20
            return 20 - fraction * 10
        case 81..<101:
            return 5
        default:
            return 0
        }
    }
}
