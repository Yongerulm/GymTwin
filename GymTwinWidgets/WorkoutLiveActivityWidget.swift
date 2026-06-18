#if canImport(ActivityKit)
import ActivityKit
import WidgetKit
import SwiftUI

/// Live Activity for an in-progress workout: a lock-screen banner and Dynamic
/// Island presentations. The elapsed time counts up live from `startedAt`
/// using `Text(_:style:.timer)`, so it animates without state pushes.
struct WorkoutLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            lockScreen(context)
                .activitySystemActionForegroundColor(DS.Palette.accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("FitPilot", systemImage: "dumbbell.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DS.Palette.accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.startedAt, style: .timer)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(DS.Palette.accent)
                        .frame(width: 64)
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.currentExercise)
                            .font(.headline)
                        Text(subtitle(context.state))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill").foregroundStyle(DS.Palette.accent)
            } compactTrailing: {
                Text(context.attributes.startedAt, style: .timer)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(DS.Palette.accent)
                    .frame(width: 44)
            } minimal: {
                Image(systemName: "dumbbell.fill").foregroundStyle(DS.Palette.accent)
            }
        }
    }

    private func subtitle(_ state: WorkoutActivityAttributes.ContentState) -> String {
        var parts = ["\(state.setsLogged) set\(state.setsLogged == 1 ? "" : "s")"]
        if let progress = state.planProgress { parts.append(progress) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func lockScreen(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "dumbbell.fill")
                .font(.title2)
                .foregroundStyle(DS.Palette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(context.state.currentExercise)
                    .font(.headline)
                Text(subtitle(context.state))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text(context.attributes.startedAt, style: .timer)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(DS.Palette.accent)
                .frame(width: 72)
                .multilineTextAlignment(.trailing)
        }
        .padding()
    }
}
#endif
