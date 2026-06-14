import SwiftUI
import SwiftData

/// 2-column grid of MachineCard for a specific GymArea.
/// Each card is a NavigationLink to MachineDetailView.
struct MachineGridView: View {

    // MARK: - Init

    let area: GymArea

    init(area: GymArea) {
        self.area = area
    }

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    // MARK: - State

    @State private var machineModel = MachineViewModel()
    @State private var showingAddMachine = false

    // MARK: - Layout

    private let columns = [
        GridItem(.flexible(), spacing: DS.Spacing.md),
        GridItem(.flexible(), spacing: DS.Spacing.md)
    ]

    // MARK: - Body

    var body: some View {
        let machines = area.sortedMachines
        ScrollView {
            if machines.isEmpty {
                EmptyStateView(
                    icon: DS.Muscle.symbol(for: area.name),
                    title: "No Machines",
                    message: "Add the equipment in your \(area.name) area.",
                    actionTitle: "Add Machine"
                ) {
                    showingAddMachine = true
                }
                .padding(.top, DS.Spacing.xxxl)
            } else {
                LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
                    ForEach(machines) { machine in
                        NavigationLink {
                            MachineDetailView(machine: machine)
                                .environment(\.modelContext, modelContext)
                        } label: {
                            gridCell(machine: machine)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.xxxl)
            }
        }
        .background(GymBackground().ignoresSafeArea())
        .navigationTitle(area.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddMachine = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
                .accessibilityLabel("Add machine to \(area.name)")
            }
        }
        .sheet(isPresented: $showingAddMachine, onDismiss: { machineModel.refresh() }) {
            MachineEditView(initialArea: area)
                .environment(\.modelContext, modelContext)
        }
        .task { machineModel.bind(modelContext) }
    }

    // MARK: - Grid cell (vertical card layout)

    private func gridCell(machine: Machine) -> some View {
        let muscleColor = DS.Muscle.color(for: area.name)
        let muscleSymbol = DS.Muscle.symbol(for: area.name)

        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Thumbnail — photo, schematic equipment icon, or muscle symbol
            MachineThumbnail(
                name: machine.name,
                imageData: machine.imageData,
                muscleColor: muscleColor,
                muscleSymbol: muscleSymbol,
                cornerRadius: DS.Radius.md
            )
            .frame(maxWidth: .infinity)
            .frame(height: 110)

            // Name
            Text(machine.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Area pill + settings badge row
            HStack(spacing: DS.Spacing.xs) {
                TagPill(text: area.name, systemImage: muscleSymbol, tint: muscleColor)
                Spacer()
                Image(systemName: machine.settings.isEmpty ? "circle" : "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(machine.settings.isEmpty ? Color.secondary : DS.Palette.success)
                    .accessibilityLabel(machine.settings.isEmpty ? "Settings incomplete" : "Settings saved")
            }
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(.white.opacity(0.07), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(machine.name), \(area.name)\(machine.settings.isEmpty ? "" : ", settings saved")")
    }
}

// MARK: - Preview

#Preview {
    let area = GymArea(name: "Chest", sortIndex: 0)
    return NavigationStack {
        MachineGridView(area: area)
    }
    .preferredColorScheme(.dark)
}
