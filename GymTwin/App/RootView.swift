import SwiftUI

/// The app's root tab container. Five training-first tabs; the workout flow is
/// presented full-screen over the whole app so it stays focused while running.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var router = AppRouter()
    @State private var gymSelection = GymSelection()

    var body: some View {
        TabView(selection: $router.selectedTab) {
            TodayView()
                .tabItem { Label("Dashboard", systemImage: "bolt.heart.fill") }
                .tag(AppTab.dashboard)

            WorkoutsHubView()
                .tabItem { Label("Workouts", systemImage: "dumbbell.fill") }
                .tag(AppTab.workouts)

            ScanTabView()
                .tabItem { Label("Scan", systemImage: "wave.3.right") }
                .tag(AppTab.scan)

            ProgressDashboardView()
                .tabItem { Label("Analytics", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppTab.analytics)

            SettingsView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
                .tag(AppTab.profile)
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
        .onChange(of: scenePhase) { _, phase in
            // Honour a "Start Workout" App Intent (Siri / widget) on activation.
            if phase == .active, WidgetIntentBridge.consumeStartWorkout() {
                router.startWorkout()
            }
        }
        .task {
            if WidgetIntentBridge.consumeStartWorkout() {
                router.startWorkout()
            }
        }
    }
}
