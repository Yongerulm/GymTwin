import SwiftUI

/// The app's root tab container. Five training-first tabs; the workout flow is
/// presented full-screen over the whole app so it stays focused while running.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var router = AppRouter()
    @State private var gymSelection = GymSelection()
    @AppStorage("has.onboarded") private var hasOnboarded = false

    var body: some View {
        TabView(selection: $router.selectedTab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "bolt.heart.fill") }
                .tag(AppTab.dashboard)

            WorkoutsHubView()
                .tabItem { Label("Train", systemImage: "dumbbell.fill") }
                .tag(AppTab.workouts)

            ProgressDashboardView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
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
            WorkoutFlowView(
                initialMachineID: router.workoutMachineID,
                scanMode: router.workoutScanMode,
                planID: router.workoutPlanID,
                scanCode: router.workoutScanCode,
                resume: router.workoutResume
            )
            .environment(router)
            .environment(gymSelection)
        }
        .onOpenURL { url in
            // Background NFC tag: gymtwin://machine/<code> → load that machine.
            guard url.scheme == "gymtwin", url.host == "machine" else { return }
            let code = url.lastPathComponent
            if !code.isEmpty, code != "machine" { router.startWorkout(scanCode: code) }
        }
        .fullScreenCover(isPresented: Binding(get: { !hasOnboarded }, set: { if $0 == false { hasOnboarded = true } })) {
            OnboardingView { hasOnboarded = true }
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
