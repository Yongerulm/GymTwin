import SwiftUI

/// Detail for a single library exercise: muscles, equipment, mechanic, and
/// step-by-step coaching cues. Pushed from `ExerciseLibraryView`.
struct ExerciseDetailView: View {
    let exercise: Exercise

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                header
                tags
                if !exercise.primaryMuscles.isEmpty || !exercise.secondaryMuscles.isEmpty {
                    musclesSection
                }
                if !exercise.instructions.isEmpty {
                    instructionsSection
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.xl)
        }
        .background(GymBackground().ignoresSafeArea())
        .navigationTitle(exercise.localizedName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DS.Spacing.lg) {
            Image(systemName: DS.Muscle.symbol(for: exercise.primaryMuscles.first ?? ""))
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(DS.Muscle.color(for: exercise.primaryMuscles.first ?? ""))
                .frame(width: 64, height: 64)
                .background(
                    DS.Muscle.color(for: exercise.primaryMuscles.first ?? "").opacity(0.14),
                    in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                )
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(exercise.localizedName)
                    .font(.title2.weight(.bold))
                if !exercise.primaryMuscles.isEmpty {
                    Text(exercise.primaryMuscles.map { LocalizedNames.muscle($0) }.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Tag row

    private var tags: some View {
        let items: [(String, String)] = [
            exercise.equipment.map { ("dumbbell.fill", LocalizedNames.term($0)) },
            exercise.mechanic.map { ("arrow.triangle.branch", LocalizedNames.term($0)) },
            ("chart.bar.fill", LocalizedNames.term(exercise.level)),
            exercise.force.map { ("arrow.up.forward", LocalizedNames.term($0)) },
        ].compactMap { $0 }

        return FlowRow(spacing: DS.Spacing.sm) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Label(item.1, systemImage: item.0)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Palette.surfaceElevated, in: Capsule())
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Muscles

    private var musclesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Muscles")
                .font(.headline)
            muscleGroup("Primary", muscles: exercise.primaryMuscles, strong: true)
            if !exercise.secondaryMuscles.isEmpty {
                muscleGroup("Secondary", muscles: exercise.secondaryMuscles, strong: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(DS.Palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
    }

    private func muscleGroup(_ title: String, muscles: [String], strong: Bool) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tertiary)
            FlowRow(spacing: DS.Spacing.sm) {
                ForEach(muscles, id: \.self) { muscle in
                    Text(LocalizedNames.muscle(muscle))
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(
                            DS.Muscle.color(for: muscle).opacity(strong ? 0.22 : 0.10),
                            in: Capsule()
                        )
                        .foregroundStyle(strong ? DS.Muscle.color(for: muscle) : .secondary)
                }
            }
        }
    }

    // MARK: - Instructions

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("How to perform")
                .font(.headline)
            ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: DS.Spacing.md) {
                    Text("\(index + 1)")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(DS.Palette.accent)
                        .frame(width: 24, height: 24)
                        .background(DS.Palette.accent.opacity(0.14), in: Circle())
                    Text(step)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(DS.Palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
    }
}

// MARK: - Simple wrapping layout

/// A lightweight flow layout that wraps its children onto new lines.
private struct FlowRow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[CGSize]] = [[]]
        var x: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append(size)
            x += size.width + spacing
        }
        let height = rows.reduce(CGFloat(0)) { acc, row in
            acc + (row.map(\.height).max() ?? 0) + spacing
        } - (rows.isEmpty ? 0 : spacing)
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: max(height, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
