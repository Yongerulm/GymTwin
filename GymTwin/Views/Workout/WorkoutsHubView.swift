import SwiftUI

/// The Workouts tab — the training hub. One tap to start an empty session,
/// plus entries into the gym digital twin and the user's training plans.
/// Owns its own `NavigationStack`; no-arg init for `TabView` wiring.
struct WorkoutsHubView: View {
    @Environment(AppRouter.self) private var router

    init() {}

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    startCard
                    quickLinks
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xl)
            }
            .background(GymBackground().ignoresSafeArea())
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Start card

    private var startCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Ready to train?")
                    .font(.title2.weight(.bold))
                Text("Start an empty session, then scan a machine to load your weights instantly.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                router.startWorkout()
            } label: {
                Label("Start Workout", systemImage: "play.fill")
            }
            .buttonStyle(GradientButtonStyle())
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .stroke(DS.Palette.accent.opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: - Quick links

    private var quickLinks: some View {
        VStack(spacing: DS.Spacing.md) {
            NavigationLink {
                GymView(embedded: true)
            } label: {
                hubRow(
                    icon: "dumbbell.fill",
                    tint: DS.Palette.accent,
                    title: "Your Gym",
                    subtitle: "Browse areas and machines"
                )
            }

            NavigationLink {
                PlansListView()
            } label: {
                hubRow(
                    icon: "list.bullet.rectangle.portrait.fill",
                    tint: DS.Palette.accentSecondary,
                    title: "Training Plans",
                    subtitle: "Build and pick your routine"
                )
            }
        }
    }

    private func hubRow(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: DS.Spacing.lg) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(DS.Spacing.lg)
        .background(DS.Palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(DS.Palette.hairline, lineWidth: 1)
        )
    }
}
