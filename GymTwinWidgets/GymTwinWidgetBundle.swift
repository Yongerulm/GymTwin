import WidgetKit
import SwiftUI

/// Entry point for the FitPilot AI widget extension: the home-screen /
/// lock-screen readiness widget plus the in-workout Live Activity.
@main
struct GymTwinWidgetBundle: WidgetBundle {
    var body: some Widget {
        ReadinessWidget()
        #if canImport(ActivityKit)
        WorkoutLiveActivityWidget()
        #endif
    }
}
