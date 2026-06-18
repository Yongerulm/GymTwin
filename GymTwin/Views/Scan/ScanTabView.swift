import SwiftUI

/// The dedicated Scan tab — the fastest path into training. Starts the
/// full-screen workout flow, which arms NFC and accepts a QR/manual code so a
/// machine loads in seconds.
struct ScanTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.xl) {
                Spacer()

                Image(systemName: "wave.3.right.circle.fill")
                    .font(.system(size: 76))
                    .foregroundStyle(DS.Palette.accentGradient)
                    .shadow(color: DS.Palette.accent.opacity(0.4), radius: 18, y: 8)

                VStack(spacing: DS.Spacing.sm) {
                    Text("Tap to train")
                        .font(.largeTitle.weight(.bold))
                    Text("Hold your iPhone to a machine's NFC tag — or enter its code — and your set loads instantly with your weights.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, DS.Spacing.xl)

                Button {
                    router.startScan()
                } label: {
                    Label("Start & Scan", systemImage: "wave.3.right")
                }
                .buttonStyle(GradientButtonStyle())
                .padding(.horizontal, DS.Spacing.xl)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(GymBackground().ignoresSafeArea())
            .navigationTitle("Scan")
        }
    }
}
