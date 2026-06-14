import SwiftUI

/// The app's signature screen background: a deep-anthracite base lit by two
/// soft, far-off accent glows (electric blue top-leading, violet
/// bottom-trailing). Gives every screen the same premium, energetic depth as
/// the gym imagery without competing with foreground content.
///
/// Used as the background of every top-level screen, e.g.
/// `.background(GymBackground().ignoresSafeArea())`.
struct GymBackground: View {
    var body: some View {
        ZStack {
            DS.Palette.background

            RadialGradient(
                colors: [DS.Palette.accent.opacity(0.16), .clear],
                center: .topLeading, startRadius: 0, endRadius: 440
            )
            RadialGradient(
                colors: [DS.Palette.accentSecondary.opacity(0.11), .clear],
                center: .bottomTrailing, startRadius: 0, endRadius: 520
            )
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    GymBackground().ignoresSafeArea()
}
