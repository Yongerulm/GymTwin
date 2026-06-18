import WidgetKit
import SwiftUI

// MARK: - Timeline

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: Date(), snapshot: WidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: Date(), snapshot: WidgetSnapshotStore.load())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())
            ?? Date().addingTimeInterval(1_800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Widget

struct ReadinessWidget: Widget {
    let kind = "ReadinessWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            ReadinessWidgetView(snapshot: entry.snapshot)
                .containerBackground(DS.Palette.background, for: .widget)
        }
        .configurationDisplayName("Readiness")
        .description("Your daily readiness, weekly goal and streak at a glance.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryRectangular, .accessoryCircular,
        ])
    }
}

// MARK: - Views

private struct ReadinessWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WidgetSnapshot

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .systemMedium: medium
        default: small
        }
    }

    private var tint: Color {
        switch snapshot.readiness {
        case ..<40: return DS.Palette.warning
        case 40..<60: return DS.Palette.record
        case 60..<80: return DS.Palette.success
        default: return DS.Palette.accent
        }
    }

    // systemSmall
    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Readiness", systemImage: "bolt.heart.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(snapshot.readiness)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("/100").font(.caption).foregroundStyle(.secondary)
            }
            Text(snapshot.readinessTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Spacer(minLength: 0)
            goalRow
        }
    }

    // systemMedium
    private var medium: some View {
        HStack(spacing: DS.Spacing.lg) {
            small
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                statRow(icon: "flame.fill", tint: DS.Palette.record,
                        value: "\(snapshot.currentStreakDays)", label: "day streak")
                statRow(icon: "checkmark.circle.fill", tint: DS.Palette.success,
                        value: "\(snapshot.workoutsThisWeek)/\(snapshot.weeklyGoal)", label: "this week")
                if let muscle = snapshot.topReadyMuscle {
                    statRow(icon: "figure.strengthtraining.traditional", tint: DS.Palette.accent,
                            value: muscle, label: "ready to train")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var goalRow: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill").font(.caption2).foregroundStyle(DS.Palette.record)
            Text("\(snapshot.currentStreakDays)d")
                .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text("·").foregroundStyle(.secondary)
            Text("\(snapshot.workoutsThisWeek)/\(snapshot.weeklyGoal)")
                .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
        }
    }

    private func statRow(icon: String, tint: Color, value: String, label: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon).font(.subheadline).foregroundStyle(tint).frame(width: 20)
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(.white)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // accessoryRectangular (lock screen)
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Readiness \(snapshot.readiness)").font(.headline)
            Text(snapshot.readinessTitle).font(.caption)
            Text("\(snapshot.workoutsThisWeek)/\(snapshot.weeklyGoal) · \(snapshot.currentStreakDays)d streak")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    // accessoryCircular (lock screen)
    private var circular: some View {
        Gauge(value: Double(snapshot.readiness), in: 0...100) {
            Image(systemName: "bolt.heart.fill")
        } currentValueLabel: {
            Text("\(snapshot.readiness)")
        }
        .gaugeStyle(.accessoryCircular)
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    ReadinessWidget()
} timeline: {
    SnapshotEntry(date: Date(), snapshot: .placeholder)
}
