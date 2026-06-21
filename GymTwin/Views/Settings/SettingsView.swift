import SwiftUI
import SwiftData

/// Top-level settings tab.
/// Sections: Apple Health · Apple Watch · Gym · Data · AI Coach · About.
struct SettingsView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var model = SettingsViewModel()

    // AI Coach toggle persists across launches.
    @AppStorage("smartRecommendationsEnabled") private var smartRecommendationsEnabled = false

    // Controls the share sheet for JSON export.
    @State private var exportItems: [Any] = []
    @State private var showingExportSheet = false

    // Language override (English / Deutsch).
    @AppStorage("app.language") private var appLanguage = "system"
    @State private var showLanguageRestart = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    appHeader
                    healthSection
                    watchSection
                    gymSection
                    dataSection
                    aiCoachSection
                    languageSection
                    toolsSection
                    aboutSection
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xl)
            }
            .background(DS.Palette.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("Restart required", isPresented: $showLanguageRestart) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Quit and reopen Gym Twin to fully apply the language.")
        }
        .task { model.bind(modelContext) }
        .sheet(isPresented: $showingExportSheet) {
            if !exportItems.isEmpty {
                ShareSheet(items: exportItems)
            }
        }
    }

    // MARK: - App Header

    private var appHeader: some View {
        SurfaceCard(padding: DS.Spacing.lg) {
            HStack(spacing: DS.Spacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(DS.Palette.accentGradient)
                        .frame(width: 54, height: 54)
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.title2)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Gym Twin")
                        .font(.title3.weight(.bold))
                    Text("Your personal gym companion")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Gym Twin, your personal gym companion")
    }

    // MARK: - Apple Health

    private var healthSection: some View {
        VStack(spacing: DS.Spacing.md) {
            PremiumSectionHeader("Apple Health")

            SurfaceCard(padding: DS.Spacing.lg) {
                VStack(spacing: DS.Spacing.lg) {
                    if !model.isHealthKitAvailable {
                        unavailableRow(
                            icon: "heart.slash",
                            message: "HealthKit is not available on this device."
                        )
                    } else if !model.healthKitAuthorized {
                        // Authorize prompt
                        VStack(spacing: DS.Spacing.md) {
                            HStack(spacing: DS.Spacing.md) {
                                Image(systemName: "heart.fill")
                                    .font(.title2)
                                    .foregroundStyle(DS.Palette.heart)
                                    .frame(width: 40, height: 40)
                                    .background(DS.Palette.heart.opacity(0.12),
                                                in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

                                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                    Text("Connect Apple Health")
                                        .font(.headline)
                                    Text("Share workouts, body weight, and heart rate.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }

                            Button {
                                Task { await model.requestHealthAccess() }
                            } label: {
                                HStack {
                                    if model.isRequestingAccess {
                                        ProgressView()
                                            .scaleEffect(0.85)
                                            .tint(.white)
                                    }
                                    Text(model.isRequestingAccess ? "Requesting…" : "Authorize")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(GradientButtonStyle())
                            .disabled(model.isRequestingAccess)
                            .accessibilityLabel("Authorize Apple Health access")
                        }
                    } else {
                        // Metrics 2-column grid
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: DS.Spacing.md),
                                      GridItem(.flexible(), spacing: DS.Spacing.md)],
                            spacing: DS.Spacing.md
                        ) {
                            MetricCard(
                                icon: "heart.fill",
                                title: "Heart Rate",
                                value: model.heartRate.map { String(format: "%.0f", $0) } ?? "—",
                                unit: model.heartRate != nil ? "bpm" : nil,
                                tint: DS.Palette.heart
                            )

                            MetricCard(
                                icon: "scalemass.fill",
                                title: "Body Weight",
                                value: model.bodyMass.map { String(format: "%.1f", $0) } ?? "—",
                                unit: model.bodyMass != nil ? "kg" : nil,
                                tint: DS.Palette.accent
                            )

                            MetricCard(
                                icon: "percent",
                                title: "Body Fat",
                                value: model.bodyFatPercent.map { String(format: "%.1f", $0) } ?? "—",
                                unit: model.bodyFatPercent != nil ? "%" : nil,
                                tint: DS.Palette.accentSecondary
                            )

                            MetricCard(
                                icon: "flame.fill",
                                title: "Active Energy",
                                value: "Auto",
                                unit: nil,
                                tint: DS.Palette.energy,
                                caption: "Saved per workout"
                            )
                        }

                        Divider()
                            .opacity(0.15)

                        Button {
                            Task { await model.loadHealthMetrics() }
                        } label: {
                            Label("Refresh Metrics", systemImage: "arrow.clockwise")
                                .font(.subheadline)
                                .foregroundStyle(DS.Palette.accent)
                                .frame(maxWidth: .infinity)
                        }
                        .accessibilityLabel("Refresh health metrics from Apple Health")
                    }
                }
            }

            if model.isHealthKitAvailable && !model.healthKitAuthorized {
                Text("Workouts are saved to Apple Health automatically after authorization.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DS.Spacing.xs)
            }
        }
    }

    // MARK: - Apple Watch

    private var watchSection: some View {
        VStack(spacing: DS.Spacing.md) {
            PremiumSectionHeader("Apple Watch")

            SurfaceCard(padding: DS.Spacing.lg) {
                HStack(spacing: DS.Spacing.lg) {
                    ZStack {
                        Circle()
                            .fill(watchStatusColor.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "applewatch")
                            .font(.title3)
                            .foregroundStyle(watchStatusColor)
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(watchStatusTitle)
                            .font(.headline)
                        Text(watchStatusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Circle()
                        .fill(watchStatusColor)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Apple Watch status: \(watchStatusTitle). \(watchStatusMessage)")
        }
    }

    private var watchStatusColor: Color {
        model.watchReachable ? DS.Palette.success : (model.watchConnected ? DS.Palette.accent : .secondary)
    }

    private var watchStatusTitle: String {
        if model.watchReachable { return "Connected" }
        if model.watchConnected { return "Paired" }
        return "Not Paired"
    }

    private var watchStatusMessage: String {
        if model.watchReachable { return "Gym Twin Watch app is active and reachable." }
        if model.watchConnected { return "Apple Watch paired — open the Gym Twin app on your watch." }
        return "Pair an Apple Watch to sync workouts in real time."
    }

    // MARK: - Gym

    private var gymSection: some View {
        VStack(spacing: DS.Spacing.md) {
            PremiumSectionHeader("Gym")

            SurfaceCard(padding: DS.Spacing.lg) {
                VStack(spacing: 0) {
                    settingsRow(
                        icon: "building.2",
                        iconTint: DS.Palette.accent,
                        label: "Name"
                    ) {
                        TextField("Gym name", text: $model.gymName)
                            .multilineTextAlignment(.trailing)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .submitLabel(.next)
                            .onSubmit { model.saveGym() }
                            .accessibilityLabel("Gym name")
                    }

                    Divider()
                        .padding(.leading, 52)
                        .opacity(0.15)

                    settingsRow(
                        icon: "mappin.and.ellipse",
                        iconTint: DS.Palette.accentSecondary,
                        label: "Location"
                    ) {
                        TextField("City, address…", text: $model.gymLocation)
                            .multilineTextAlignment(.trailing)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .submitLabel(.done)
                            .onSubmit { model.saveGym() }
                            .accessibilityLabel("Gym location")
                    }
                }
            }
            .onChange(of: model.gymName) { _, _ in model.saveGym() }
            .onChange(of: model.gymLocation) { _, _ in model.saveGym() }

            Text("Changes are saved automatically when you dismiss the keyboard.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.xs)
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        VStack(spacing: DS.Spacing.md) {
            PremiumSectionHeader("Data")

            SurfaceCard(padding: DS.Spacing.lg) {
                Button {
                    exportWorkouts()
                } label: {
                    HStack(spacing: DS.Spacing.md) {
                        ZStack {
                            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                                .fill(DS.Palette.accentSecondary.opacity(0.15))
                                .frame(width: 34, height: 34)
                            Image(systemName: "square.and.arrow.up")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DS.Palette.accentSecondary)
                        }

                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text("Export Workouts")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("Save all workout data as JSON")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Export workouts as JSON file")
            }
        }
    }

    // MARK: - AI Coach

    private var aiCoachSection: some View {
        VStack(spacing: DS.Spacing.md) {
            PremiumSectionHeader("AI Coach")

            SurfaceCard(padding: DS.Spacing.lg) {
                VStack(spacing: DS.Spacing.lg) {
                    HStack(spacing: DS.Spacing.md) {
                        ZStack {
                            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                                .fill(DS.Palette.accent.opacity(0.15))
                                .frame(width: 34, height: 34)
                            Image(systemName: "sparkles")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DS.Palette.accent)
                        }

                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            HStack(spacing: DS.Spacing.xs) {
                                Text("Smart Recommendations")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)

                                TagPill(text: "Beta", tint: DS.Palette.accentSecondary)
                            }
                            Text("Personalised set suggestions based on your history.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: $smartRecommendationsEnabled)
                            .labelsHidden()
                            .accessibilityLabel("Enable smart workout recommendations")
                    }

                    if smartRecommendationsEnabled {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "clock.badge.questionmark")
                                .font(.caption)
                                .foregroundStyle(DS.Palette.accentSecondary)
                            Text("Recommendations will appear during your workouts once enough training history is available.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(DS.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DS.Palette.accent.opacity(0.07),
                                    in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .animation(DS.Motion.spring, value: smartRecommendationsEnabled)
            }
        }
    }

    // MARK: - Tools

    private var toolsSection: some View {
        VStack(spacing: DS.Spacing.md) {
            PremiumSectionHeader("Tools")

            SurfaceCard(padding: DS.Spacing.lg) {
                VStack(spacing: 0) {
                    NavigationLink(destination: PlansListView()) {
                        toolsRow(
                            icon: "calendar.badge.plus",
                            iconTint: DS.Palette.success,
                            label: "Training Plans",
                            caption: "Build plans from your machines"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Training Plans")

                    Divider()
                        .padding(.leading, 52)
                        .opacity(0.15)

                    NavigationLink(destination: ProfileView()) {
                        toolsRow(
                            icon: "person.crop.circle",
                            iconTint: DS.Palette.accentSecondary,
                            label: "Profile",
                            caption: "Goals, body metrics & training age"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Profile settings")

                    Divider()
                        .padding(.leading, 52)
                        .opacity(0.15)

                    NavigationLink(destination: AdminPanelView()) {
                        toolsRow(
                            icon: "wrench.and.screwdriver.fill",
                            iconTint: DS.Palette.warning,
                            label: "Admin",
                            caption: "Machine catalog, sync & AI rules"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Admin panel")
                }
            }
        }
    }

    @ViewBuilder
    private func toolsRow(icon: String, iconTint: Color, label: String, caption: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .fill(iconTint.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(iconTint)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, DS.Spacing.sm)
        .contentShape(Rectangle())
    }

    // MARK: - About

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            PremiumSectionHeader("Language", subtitle: "App language")
            SurfaceCard {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Picker("Language", selection: $appLanguage) {
                        Text("System").tag("system")
                        Text("English").tag("en")
                        Text("Deutsch").tag("de")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: appLanguage) { _, newValue in applyLanguage(newValue) }
                    Text("Switches the whole app — interface, exercises and machines.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func applyLanguage(_ value: String) {
        switch value {
        case "en": UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        case "de": UserDefaults.standard.set(["de"], forKey: "AppleLanguages")
        default: UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        showLanguageRestart = true
    }

    private var aboutSection: some View {
        VStack(spacing: DS.Spacing.md) {
            PremiumSectionHeader("About")

            SurfaceCard(padding: DS.Spacing.lg) {
                VStack(spacing: 0) {
                    settingsRow(
                        icon: "info.circle",
                        iconTint: DS.Palette.accentSecondary,
                        label: "Version"
                    ) {
                        Text("1.0.0")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Divider()
                        .padding(.leading, 52)
                        .opacity(0.15)

                    HStack(spacing: DS.Spacing.md) {
                        ZStack {
                            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                                .fill(DS.Palette.success.opacity(0.15))
                                .frame(width: 34, height: 34)
                            Image(systemName: "wifi.slash")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DS.Palette.success)
                        }

                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text("Offline-First")
                                .font(.subheadline.weight(.semibold))
                            Text("All your data lives on-device. No account or cloud sync required.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, DS.Spacing.sm)
                }
            }
        }
    }

    // MARK: - Helpers

    /// A standard iOS-style settings row: icon chip · label · trailing content.
    @ViewBuilder
    private func settingsRow<Trailing: View>(
        icon: String,
        iconTint: Color,
        label: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .fill(iconTint.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(iconTint)
            }

            Text(label)
                .font(.subheadline)

            Spacer()

            trailing()
        }
        .padding(.vertical, DS.Spacing.sm)
    }

    @ViewBuilder
    private func unavailableRow(icon: String, message: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 40)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Export

    private func exportWorkouts() {
        let workoutService = WorkoutService(context: modelContext)
        let workouts = workoutService.allWorkouts()
        let dtos = workouts.map { WorkoutDTO(workout: $0) }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(dtos) else { return }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GymTwin-workouts.json")
        try? data.write(to: url)

        exportItems = [url]
        showingExportSheet = true
    }
}

// MARK: - ShareSheet

/// UIActivityViewController wrapped for SwiftUI.
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    SettingsView()
        .modelContainer(for: [Gym.self, Workout.self], inMemory: true)
        .preferredColorScheme(.dark)
}
