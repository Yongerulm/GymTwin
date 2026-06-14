import SwiftUI

/// The app's root tab container. Four training-first tabs; the workout flow is
/// presented full-screen over the whole app so it stays focused while running.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var router = AppRouter()
    @State private var gymSelection = GymSelection()

    var body: some View {
        TabView(selection: $router.selectedTab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "bolt.heart.fill") }
                .tag(AppTab.today)

            GymView()
                .tabItem { Label("Gym", systemImage: "dumbbell.fill") }
                .tag(AppTab.gym)

            ProgressDashboardView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppTab.progress)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .tint(DS.Palette.accent)
        .preferredColorScheme(.dark)
        .environment(router)
        .environment(gymSelection)
        .fullScreenCover(isPresented: $router.isWorkoutActive) {
            WorkoutFlowView(initialMachineID: router.workoutMachineID)
                .environment(router)
                .environment(gymSelection)
        }
    }
}
