import SwiftUI

/// Two-in-one view: machine list (grouped by area) and machine detail.
///
/// When `selectionMode` is `true` (launched from Start Workout or the active
/// workout card), tapping a machine adds it to the workout and jumps straight
/// to `WatchSetLoggingView`. When `false` it acts as a plain machine browser
/// with a detail sheet that shows settings and a start/add CTA.
struct WatchMachineView: View {
    @Environment(WatchDataStore.self) private var store

    /// `true` → picking a machine starts/adds to the active workout.
    var selectionMode: Bool = false

    // Machines grouped and sorted by area.
    private var grouped: [(area: String, machines: [MachineDTO])] {
        Dictionary(grouping: store.catalog, by: \.areaName)
            .sorted { $0.key < $1.key }
            .map { key, value in
                (area: key, machines: value.sorted { $0.name < $1.name })
            }
    }

    var body: some View {
        List {
            ForEach(grouped, id: \.area) { group in
                Section(group.area.isEmpty ? "General" : group.area) {
                    ForEach(group.machines) { machine in
                        machineRow(machine)
                    }
                }
            }
        }
        .navigationTitle(selectionMode ? "Pick Machine" : "Machines")
    }

    // MARK: - Row

    @ViewBuilder
    private func machineRow(_ machine: MachineDTO) -> some View {
        if selectionMode {
            // Selection mode: tap → add exercise → log sets
            NavigationLink(destination: WatchSetLoggingViewForMachine(machine: machine)) {
                machineLabel(machine)
            }
        } else {
            // Browse mode: tap → machine detail
            NavigationLink(destination: WatchMachineDetailView(machine: machine)) {
                machineLabel(machine)
            }
        }
    }

    private func machineLabel(_ machine: MachineDTO) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: DS.Muscle.symbol(for: machine.areaName))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DS.Muscle.color(for: machine.areaName))
                .frame(width: 24, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(machine.name)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                if !machine.category.isEmpty {
                    Text(machine.category)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityLabel("\(machine.name), \(machine.areaName)")
    }
}

// MARK: - Machine detail (browse mode)

/// Shows the machine's saved settings in a large, glanceable layout and
/// provides a prominent CTA to start a workout or add to the active one.
private struct WatchMachineDetailView: View {
    @Environment(WatchDataStore.self) private var store
    let machine: MachineDTO

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {

                // Area / category badge
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: DS.Muscle.symbol(for: machine.areaName))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.Muscle.color(for: machine.areaName))
                    Text(machine.areaName.isEmpty ? machine.category : machine.areaName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.Muscle.color(for: machine.areaName))
                        .textCase(.uppercase)
                        .tracking(0.5)
                }

                // Settings
                if machine.settings.isEmpty {
                    Text("No saved settings")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(machine.settings) { setting in
                        settingRow(setting)
                    }
                }

                // Notes
                if !machine.notes.isEmpty {
                    Divider()
                    Text(machine.notes)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                // CTA — navigates to set-logging screen
                NavigationLink(destination: WatchSetLoggingViewForMachine(machine: machine)) {
                    Label(
                        store.isWorkoutActive ? "Add to Workout" : "Start Workout",
                        systemImage: store.isWorkoutActive ? "plus.circle.fill" : "play.fill"
                    )
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Palette.accent, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(.top, DS.Spacing.xs)
                .accessibilityLabel(
                    store.isWorkoutActive
                        ? "Add \(machine.name) to workout"
                        : "Start workout with \(machine.name)"
                )
            }
            .padding(DS.Spacing.md)
        }
        .navigationTitle(machine.name)
    }

    private func settingRow(_ setting: MachineSettingDTO) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(setting.title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: 80, alignment: .leading)
            Spacer(minLength: DS.Spacing.xs)
            Text(setting.value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, DS.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(setting.title): \(setting.value)")
    }
}

// MARK: - Helper: add machine then route to set-logging

/// Thin wrapper that calls `store.addExercise(_:)` and routes to
/// `WatchSetLoggingView` with the resulting exercise index. This avoids
/// embedding navigation logic inside `NavigationLink` closures.
private struct WatchSetLoggingViewForMachine: View {
    @Environment(WatchDataStore.self) private var store
    let machine: MachineDTO

    @State private var exerciseIndex: Int?

    var body: some View {
        Group {
            if let idx = exerciseIndex {
                WatchSetLoggingView(exerciseIndex: idx)
            } else {
                ProgressView()
                    .onAppear {
                        exerciseIndex = store.addExercise(machine)
                    }
            }
        }
    }
}
