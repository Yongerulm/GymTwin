import SwiftUI

/// Top-level NavigationStack. Shows an empty-catalog prompt when no data has
/// been synced from the iPhone, otherwise hosts WatchTodayView.
struct WatchRootView: View {
    @Environment(WatchDataStore.self) private var store

    var body: some View {
        NavigationStack {
            if store.catalog.isEmpty {
                syncPrompt
            } else {
                WatchTodayView()
            }
        }
    }

    // MARK: - Empty state

    private var syncPrompt: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(DS.Palette.accent)

            Text("Open Gym Twin\non iPhone to sync")
                .font(.system(size: 14, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
        }
        .padding(DS.Spacing.lg)
        .navigationTitle("Gym Twin")
    }
}
