import SwiftUI
import SwiftData

/// Top-level Gym tab — the digital twin of the user's gym.
/// Areas are shown as beautiful muscle-coloured cards; each card
/// previews its machines and navigates to a full MachineGridView.
/// Global search filters across all machines. Toolbar "+" adds a machine.
struct GymView: View {

    // MARK: - Init

    init() {}

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    // MARK: - Query — live SwiftData lists

    @Query(sort: \GymArea.sortIndex) private var areas: [GymArea]
    @Query(sort: \Machine.sortIndex) private var allMachines: [Machine]
    @Query(sort: \Gym.createdDate) private var gyms: [Gym]

    @Environment(GymSelection.self) private var gymSelection

    // MARK: - State

    @State private var gymModel = GymViewModel()
    @State private var machineModel = MachineViewModel()
    @State private var searchText = ""
    @State private var showingAddMachine = false
    @State private var showingAddArea = false
    @State private var newAreaName = ""
    @State private var showingAddGym = false
    @State private var newGymName = ""

    // MARK: - Active gym scoping

    /// The gym the user is currently training in (selected via the switcher).
    private var activeGym: Gym? { gymSelection.activeGym(from: gyms) }

    /// Areas belonging to the active gym only.
    private var displayedAreas: [GymArea] { activeGym?.sortedAreas ?? [] }

    /// Machines belonging to the active gym (across its areas).
    private var activeMachines: [Machine] { displayedAreas.flatMap { $0.sortedMachines } }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if displayedAreas.isEmpty && searchText.isEmpty {
                    emptyGymState
                } else if !searchText.isEmpty {
                    searchResultsView
                } else {
                    areasScrollView
                }
            }
            .navigationTitle(activeGym?.name ?? "Gym")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search machines"
            )
            .toolbar { toolbarItems }
            .sheet(isPresented: $showingAddMachine, onDismiss: { machineModel.refresh() }) {
                MachineEditView()
                    .environment(\.modelContext, modelContext)
            }
            .alert("New Area", isPresented: $showingAddArea) {
                TextField("Area name (e.g. Chest, Back)", text: $newAreaName)
                    .autocorrectionDisabled()
                Button("Add") { commitNewArea() }
                    .disabled(newAreaName.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Cancel", role: .cancel) { newAreaName = "" }
            } message: {
                Text("Give this muscle group or zone a name.")
            }
            .alert("New Gym", isPresented: $showingAddGym) {
                TextField("Gym name (e.g. SRC, Home Gym)", text: $newGymName)
                    .autocorrectionDisabled()
                Button("Add") { commitNewGym() }
                    .disabled(newGymName.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Cancel", role: .cancel) { newGymName = "" }
            } message: {
                Text("Add another gym you train in. You can switch any time.")
            }
            .task {
                gymModel.bind(modelContext)
                machineModel.bind(modelContext)
            }
            .onChange(of: allMachines) { machineModel.refresh() }
        }
    }

    // MARK: - Main scrollable content

    private var areasScrollView: some View {
        ScrollView {
            LazyVStack(spacing: DS.Spacing.xl) {
                // Header stat row
                gymStatsRow
                    .padding(.horizontal, DS.Spacing.lg)

                // One area card per gym area (active gym only)
                ForEach(displayedAreas) { area in
                    AreaCard(area: area)
                        .padding(.horizontal, DS.Spacing.lg)
                }

                // Unassigned machines section
                let unassigned = allMachines.filter { $0.area == nil }
                if !unassigned.isEmpty {
                    unassignedSection(machines: unassigned)
                        .padding(.horizontal, DS.Spacing.lg)
                }
            }
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.xxxl)
        }
        .background(GymBackground().ignoresSafeArea())
    }

    // MARK: - Gym stats bar

    private var gymStatsRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            miniStat(value: "\(displayedAreas.count)", label: "Areas", icon: "map.fill")
            Divider().frame(height: 28)
            miniStat(value: "\(activeMachines.count)", label: "Machines", icon: "dumbbell.fill")
            Divider().frame(height: 28)
            let configured = activeMachines.filter { !$0.settings.isEmpty }.count
            miniStat(value: "\(configured)", label: "Configured", icon: "checkmark.circle.fill", tint: DS.Palette.success)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .strokeBorder(.white.opacity(0.07), lineWidth: 1)
        )
    }

    private func miniStat(value: String, label: String, icon: String, tint: Color = DS.Palette.accent) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    // MARK: - Unassigned section

    private func unassignedSection(machines: [Machine]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "tray.fill")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Uncategorized")
                    .font(.title3.weight(.bold))
                Spacer()
                Text("\(machines.count)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(.secondary.opacity(0.15), in: Capsule())
            }

            ForEach(machines) { machine in
                NavigationLink {
                    MachineDetailView(machine: machine)
                        .environment(\.modelContext, modelContext)
                } label: {
                    MachineCard(
                        name: machine.name,
                        category: machine.category,
                        areaName: nil,
                        imageData: machine.imageData,
                        lastUsed: nil,
                        settingsComplete: !machine.settings.isEmpty,
                        action: {}
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 14, x: 0, y: 7)
    }

    // MARK: - Search results

    private var searchResultsView: some View {
        let results = filteredMachines
        return ScrollView {
            LazyVStack(spacing: DS.Spacing.sm) {
                if results.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No Results",
                        message: "No machines match \"\(searchText)\"."
                    )
                    .padding(.top, DS.Spacing.xxxl)
                } else {
                    PremiumSectionHeader(
                        "\(results.count) result\(results.count == 1 ? "" : "s")",
                        subtitle: "Matching \"\(searchText)\""
                    )
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.md)

                    ForEach(results) { machine in
                        NavigationLink {
                            MachineDetailView(machine: machine)
                                .environment(\.modelContext, modelContext)
                        } label: {
                            MachineCard(
                                name: machine.name,
                                category: machine.category,
                                areaName: machine.area?.name,
                                imageData: machine.imageData,
                                lastUsed: nil,
                                settingsComplete: !machine.settings.isEmpty,
                                action: {}
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, DS.Spacing.lg)
                    }
                }
            }
            .padding(.bottom, DS.Spacing.xxxl)
        }
        .background(GymBackground().ignoresSafeArea())
    }

    // MARK: - Empty state

    private var emptyGymState: some View {
        EmptyStateView(
            icon: "building.2.fill",
            title: "Build Your Gym",
            message: "Add areas (Chest, Back, Legs…) and then populate them with machines.",
            actionTitle: "Add First Area"
        ) {
            showingAddArea = true
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GymBackground().ignoresSafeArea())
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            gymSwitcher
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    showingAddMachine = true
                } label: {
                    Label("Add Machine", systemImage: "dumbbell.fill")
                }
                Button {
                    showingAddArea = true
                } label: {
                    Label("Add Area", systemImage: "plus.square.fill")
                }
            } label: {
                Image(systemName: "plus")
                    .fontWeight(.semibold)
            }
            .accessibilityLabel("Add machine or area")
        }
    }

    /// Switches the active gym and offers to add a new one.
    private var gymSwitcher: some View {
        Menu {
            ForEach(gyms) { gym in
                Button {
                    gymSelection.activeGymID = gym.id
                } label: {
                    if gym.id == activeGym?.id {
                        Label(gym.name, systemImage: "checkmark")
                    } else {
                        Text(gym.name)
                    }
                }
            }
            Divider()
            Button {
                showingAddGym = true
            } label: {
                Label("Add Gym", systemImage: "plus")
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "building.2.fill").font(.caption)
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
            .foregroundStyle(DS.Palette.accent)
        }
        .accessibilityLabel("Switch gym, currently \(activeGym?.name ?? "none")")
    }

    // MARK: - Helpers

    private func commitNewArea() {
        let trimmed = newAreaName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let gym = activeGym else { newAreaName = ""; return }
        let nextIndex = (gym.areas.map(\.sortIndex).max() ?? -1) + 1
        let area = GymArea(name: trimmed, sortIndex: nextIndex)
        area.gym = gym
        gym.areas.append(area)
        modelContext.insert(area)
        try? modelContext.save()
        newAreaName = ""
    }

    private func commitNewGym() {
        let trimmed = newGymName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { newGymName = ""; return }
        let gym = Gym(name: trimmed, location: "")
        modelContext.insert(gym)
        try? modelContext.save()
        gymSelection.activeGymID = gym.id
        newGymName = ""
    }

    private var filteredMachines: [Machine] {
        let query = searchText.lowercased()
        return allMachines.filter {
            $0.name.lowercased().contains(query)
                || $0.category.lowercased().contains(query)
                || ($0.area?.name.lowercased().contains(query) == true)
        }
    }
}

// MARK: - AreaCard

/// A rich area card showing muscle colour, icon, machine count and a
/// horizontal preview strip of up to 4 machines. Taps navigate to
/// MachineGridView for the full grid.
private struct AreaCard: View {
    let area: GymArea
    @Environment(\.modelContext) private var modelContext

    private var muscleColor: Color { DS.Muscle.color(for: area.name) }
    private var muscleSymbol: String { DS.Muscle.symbol(for: area.name) }
    private var machines: [Machine] { area.sortedMachines }

    var body: some View {
        NavigationLink {
            MachineGridView(area: area)
                .environment(\.modelContext, modelContext)
        } label: {
            cardBody
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(area.name) area, \(machines.count) machine\(machines.count == 1 ? "" : "s")")
        .accessibilityHint("Opens machine grid for \(area.name)")
    }

    private var cardBody: some View {
        VStack(spacing: 0) {
            heroBanner
            // Machine preview strip / empty hint
            Group {
                if !machines.isEmpty {
                    machinePreviewStrip
                } else {
                    Text("No machines yet — tap to add one")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(DS.Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Palette.surface)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(muscleColor.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 6)
    }

    /// Energetic, muscle-specific hero image with a dark scrim and the area
    /// title overlaid. Falls back to a muscle-coloured gradient if the image
    /// asset is missing.
    private var heroBanner: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let imageName = DS.Muscle.imageName(for: area.name) {
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(colors: [muscleColor, muscleColor.opacity(0.4)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 124)
            .clipped()

            // Legibility scrim
            LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.72)],
                           startPoint: .top, endPoint: .bottom)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: muscleSymbol)
                            .font(.subheadline.weight(.bold))
                        Text(area.name)
                            .font(.title3.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    Text("\(machines.count) machine\(machines.count == 1 ? "" : "s")")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.82))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(DS.Spacing.md)
            .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 1)
        }
        .frame(height: 124)
    }

    private var machinePreviewStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(machines.prefix(5)) { machine in
                    machineThumb(machine)
                }
                if machines.count > 5 {
                    ZStack {
                        RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                            .fill(.white.opacity(0.06))
                        Text("+\(machines.count - 5)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 52, height: 52)
                }
            }
        }
        .allowsHitTesting(false) // Let the card button handle the tap
    }

    private func machineThumb(_ machine: Machine) -> some View {
        Group {
            if let data = machine.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    muscleColor.opacity(0.20)
                    Image(systemName: MachineArt.symbol(for: machine.name) ?? muscleSymbol)
                        .font(.system(size: 20, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .accessibilityLabel(machine.name)
    }
}

// MARK: - Preview

#Preview {
    GymView()
        .preferredColorScheme(.dark)
}
