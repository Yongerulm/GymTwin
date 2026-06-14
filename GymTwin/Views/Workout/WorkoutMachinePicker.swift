import SwiftUI
import SwiftData

/// Searchable machine list grouped by area.
/// Presented as a sheet to add a machine to the active session.
struct WorkoutMachinePicker: View {
    let onSelect: (Machine) -> Void
    let onDismiss: () -> Void

    @Query(sort: \Machine.name) private var allMachines: [Machine]
    @State private var searchText = ""

    // MARK: - Filtered + grouped data

    private var filtered: [Machine] {
        guard !searchText.isEmpty else { return allMachines }
        let q = searchText.lowercased()
        return allMachines.filter {
            $0.name.lowercased().contains(q) ||
            $0.category.lowercased().contains(q) ||
            ($0.area?.name.lowercased().contains(q) ?? false)
        }
    }

    /// Machines grouped by area name, "No Area" as fallback bucket.
    private var grouped: [(areaName: String, machines: [Machine])] {
        var dict: [String: [Machine]] = [:]
        for machine in filtered {
            let key = machine.area?.name ?? "No Area"
            dict[key, default: []].append(machine)
        }
        return dict
            .map { (areaName: $0.key, machines: $0.value.sorted { $0.sortIndex < $1.sortIndex }) }
            .sorted { $0.areaName < $1.areaName }
    }

    var body: some View {
        NavigationStack {
            Group {
                if allMachines.isEmpty {
                    EmptyStateView(
                        icon: "dumbbell",
                        title: "No machines",
                        message: "Add machines to your gym catalog first.",
                        actionTitle: nil,
                        action: nil
                    )
                } else if filtered.isEmpty {
                    emptySearch
                } else {
                    machineList
                }
            }
            .navigationTitle("Add Machine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search machines or areas"
            )
        }
    }

    // MARK: - Machine list

    private var machineList: some View {
        List {
            ForEach(grouped, id: \.areaName) { group in
                Section {
                    ForEach(group.machines) { machine in
                        MachinePickerRow(machine: machine) {
                            onSelect(machine)
                        }
                    }
                } header: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: DS.Muscle.symbol(for: group.areaName))
                            .font(.caption2)
                            .foregroundStyle(DS.Muscle.color(for: group.areaName))
                        Text(group.areaName)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty search state

    private var emptySearch: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
            Text("No results for \"\(searchText)\"")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DS.Spacing.xl)
    }
}

// MARK: - Row

private struct MachinePickerRow: View {
    let machine: Machine
    let onSelect: () -> Void

    private var muscleColor: Color {
        DS.Muscle.color(for: machine.area?.name ?? machine.category)
    }

    private var muscleSymbol: String {
        DS.Muscle.symbol(for: machine.area?.name ?? machine.category)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DS.Spacing.md) {
                // Muscle-tinted badge
                Image(systemName: muscleSymbol)
                    .font(.body.weight(.medium))
                    .foregroundStyle(muscleColor)
                    .frame(width: 38, height: 38)
                    .background(
                        muscleColor.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(machine.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    if !machine.category.isEmpty {
                        Text(machine.category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "plus.circle")
                    .font(.title3)
                    .foregroundStyle(DS.Palette.accent)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add \(machine.name) to session")
        .accessibilityHint("Double-tap to add this machine")
    }
}

// MARK: - Preview

#Preview("WorkoutMachinePicker") {
    WorkoutMachinePicker(
        onSelect: { _ in },
        onDismiss: {}
    )
    .preferredColorScheme(.dark)
}
