import SwiftUI

/// First-run welcome: three quick pages that establish what Gym Twin does and
/// how to start, so a new user reaches first value fast. Shown once
/// (gated by `@AppStorage("has.onboarded")`), then dismissed.
struct OnboardingView: View {
    let onDone: () -> Void

    @State private var page = 0

    private let pages: [(icon: String, title: String, body: String)] = [
        ("bolt.heart.fill", "Welcome to Gym Twin",
         "Your gym's digital twin. Build a plan once, then just train — your weights and targets are always one tap away."),
        ("wave.3.right", "Tap to load a machine",
         "Hold your iPhone to a machine's NFC tag (or scan its code) and your predefined set loads instantly, ready to log."),
        ("checkmark.seal.fill", "Follow your plan",
         "Pick a plan, work through each machine, and Complete Set logs at your target and starts your rest. Progress tracks itself."),
    ]

    var body: some View {
        ZStack {
            DS.Palette.background.ignoresSafeArea()
            DS.Palette.heroHalo.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { idx, p in
                        pageView(p).tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button {
                    if page < pages.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        onDone()
                    }
                } label: {
                    Text(page < pages.count - 1 ? "Next" : "Get Started")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GradientButtonStyle())
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.lg)

                Button("Skip", action: onDone)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, DS.Spacing.lg)
                    .opacity(page < pages.count - 1 ? 1 : 0)
                    .accessibilityHidden(page >= pages.count - 1)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func pageView(_ p: (icon: String, title: String, body: String)) -> some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            Image(systemName: p.icon)
                .font(.system(size: 64))
                .foregroundStyle(DS.Palette.accentGradient)
                .accessibilityHidden(true)
            VStack(spacing: DS.Spacing.md) {
                Text(p.title)
                    .font(.largeTitle.weight(.heavy))
                    .multilineTextAlignment(.center)
                Text(p.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xl)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(p.title). \(p.body)")
    }
}
