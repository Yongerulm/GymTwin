import SwiftUI

// MARK: - PremiumSectionHeader

/// Section header with optional subtitle and trailing action button.
struct PremiumSectionHeader: View {
    let title: String
    var subtitle: String?
    var actionTitle: String?
    var action: (() -> Void)?

    init(_ title: String, subtitle: String? = nil, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2.weight(.bold))
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.Palette.accent)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - HeroWorkoutCard

/// Big hero card used on the Today tab. Combines a radial halo background,
/// accent gradient bar, a summary line and a prominent start button.
struct HeroWorkoutCard: View {
    let title: String
    let subtitle: String
    let dateText: String
    let lastSummary: String?
    /// Current training streak, shown as a flame pill when > 0.
    var streakDays: Int? = nil
    let startAction: () -> Void

    var body: some View {
        ZStack {
            // Ember gradient base
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: "#FF7A40"), Color(hex: "#E84A00"), Color(hex: "#B82800")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))

            // Top white highlight (covers upper portion)
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.14), .clear], startPoint: .top, endPoint: .center))

            // Bottom-right radial glow
            RadialGradient(colors: [.white.opacity(0.10), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 240)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))

            VStack(alignment: .leading, spacing: 0) {
                // Top: date caps + headline, streak pill on the right
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(dateText.uppercased())
                            .font(.system(size: 9, weight: .medium)).tracking(1.3)
                            .foregroundStyle(.white.opacity(0.7))
                        Text(title)
                            .font(.system(size: 28, weight: .heavy)).tracking(-0.6)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: DS.Spacing.sm)
                    if let streakDays, streakDays > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill").font(.system(size: 11, weight: .bold))
                            Text("\(streakDays) day\(streakDays == 1 ? "" : "s")").font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.white.opacity(0.22), in: Capsule())
                    }
                }

                Spacer(minLength: DS.Spacing.lg)

                // Bottom: dim stats + white START button
                HStack(alignment: .bottom) {
                    Text(lastSummary ?? subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: DS.Spacing.md)
                    Button(action: startAction) {
                        HStack(spacing: 6) {
                            Text("START").font(.system(size: 13, weight: .heavy))
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .heavy))
                        }
                        .foregroundStyle(Color(hex: "#C83400"))
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Start workout")
                }
            }
            .padding(18)
        }
        .frame(minHeight: 172)
        .shadow(color: DS.Palette.accent.opacity(0.28), radius: 22, x: 0, y: 12)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - MachineCard

/// Tappable card for a gym machine. Shows a thumbnail (photo or gradient +
/// muscle symbol), name, muscle TagPill, last-used date and a settings badge.
struct MachineCard: View {
    let name: String
    let category: String
    let areaName: String?
    let imageData: Data?
    let lastUsed: Date?
    let settingsComplete: Bool
    let action: () -> Void

    private var muscleColor: Color {
        DS.Muscle.color(for: areaName ?? category)
    }

    private var muscleSymbol: String {
        DS.Muscle.symbol(for: areaName ?? category)
    }

    private var lastUsedText: String? {
        guard let lastUsed else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastUsed, relativeTo: Date())
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.lg) {
                // Thumbnail
                thumbnailView
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))

                // Text block
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let areaName {
                        TagPill(
                            text: areaName,
                            systemImage: muscleSymbol,
                            tint: muscleColor
                        )
                    }

                    if let lastUsedText {
                        Text(lastUsedText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Settings badge
                Image(systemName: settingsComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(settingsComplete ? DS.Palette.success : Color.secondary)
                    .accessibilityLabel(settingsComplete ? "Settings complete" : "Settings incomplete")
            }
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(DS.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .strokeBorder(.white.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(areaName ?? category)\(lastUsedText.map { ", last used \($0)" } ?? "")")
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let imageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else if let asset = MachineArt.assetName(for: name) {
            Image(asset)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [muscleColor.opacity(0.6), muscleColor.opacity(0.25)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: MachineArt.symbol(for: name) ?? muscleSymbol)
                    .font(.system(size: 30, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - MachineSettingChip

/// Small chip showing a setting title above a large, legible value.
struct MachineSettingChip: View {
    let title: String
    let value: String
    var tint: Color = DS.Palette.accent

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(tint.opacity(0.8))
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .frame(minWidth: 64, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .strokeBorder(tint.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - MetricCard

/// Icon chip, large value+unit, title and optional caption.
struct MetricCard: View {
    let icon: String
    let title: String
    let value: String
    var unit: String?
    var tint: Color = DS.Palette.accent
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Icon chip
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

            // Value row
            HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                Text(value)
                    .font(.largeTitle.weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if let unit {
                    Text(unit)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 14, x: 0, y: 7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)\(unit.map { " \($0)" } ?? "")\(caption.map { ". \($0)" } ?? "")")
    }
}

// MARK: - ProgressRingCard

/// Circular progress ring (0…1) with a centred value/label pair.
struct ProgressRingCard: View {
    let title: String
    let progress: Double
    let centerValue: String
    let centerLabel: String
    var tint: Color = DS.Palette.accent

    private let ringSize: CGFloat = 110
    private let lineWidth: CGFloat = 10

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                // Track
                Circle()
                    .stroke(.white.opacity(0.07), lineWidth: lineWidth)

                // Progress arc with gradient
                Circle()
                    .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                    .stroke(
                        AngularGradient(
                            colors: [tint, tint.opacity(0.5)],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(DS.Motion.spring, value: progress)

                // Centre labels
                VStack(spacing: 2) {
                    Text(centerValue)
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(centerLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: ringSize, height: ringSize)
            .frame(maxWidth: .infinity)
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 14, x: 0, y: 7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(centerValue) \(centerLabel), \(Int(progress * 100)) percent")
    }
}

// MARK: - Previews

#Preview("PremiumSectionHeader") {
    VStack(spacing: DS.Spacing.xl) {
        PremiumSectionHeader("Recent Workouts", subtitle: "Last 7 days")
        PremiumSectionHeader("Machines", subtitle: "Chest area", actionTitle: "See all") {}
    }
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("HeroWorkoutCard") {
    HeroWorkoutCard(
        title: "Chest Day",
        subtitle: "6 exercises · 45 min",
        dateText: "Today",
        lastSummary: "Last time: 5 sets · 2,340 kg total",
        startAction: {}
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("MachineCard") {
    VStack(spacing: DS.Spacing.md) {
        MachineCard(name: "Chest Press", category: "Chest", areaName: "Chest", imageData: nil, lastUsed: Date().addingTimeInterval(-86400), settingsComplete: true, action: {})
        MachineCard(name: "Leg Press", category: "Legs", areaName: "Legs", imageData: nil, lastUsed: nil, settingsComplete: false, action: {})
    }
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("MachineSettingChip") {
    HStack(spacing: DS.Spacing.md) {
        MachineSettingChip(title: "Weight", value: "57.5 kg")
        MachineSettingChip(title: "Reps", value: "10", tint: DS.Palette.accentSecondary)
        MachineSettingChip(title: "Sets", value: "3", tint: DS.Palette.success)
    }
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("MetricCard") {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.md) {
        MetricCard(icon: "flame.fill", title: "Total Volume", value: "12,450", unit: "kg", tint: DS.Palette.energy, caption: "This week")
        MetricCard(icon: "trophy.fill", title: "Personal Record", value: "120", unit: "kg", tint: DS.Palette.record)
    }
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("ProgressRingCard") {
    HStack(spacing: DS.Spacing.md) {
        ProgressRingCard(title: "Weekly Goal", progress: 0.72, centerValue: "4", centerLabel: "of 5", tint: DS.Palette.accent)
        ProgressRingCard(title: "Volume Goal", progress: 0.45, centerValue: "45%", centerLabel: "done", tint: DS.Palette.success)
    }
    .padding()
    .preferredColorScheme(.dark)
}
