import SwiftUI
import SwiftData

/// Browsable, searchable library over the 1000+ bundled exercises. Filters by
/// muscle and equipment and full-text searches the name. Pushed from the
/// Workouts hub, so it renders without its own `NavigationStack`.
struct ExerciseLibraryView: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var searchText = ""
    @State private var selectedMuscle: String?
    @State private var selectedEquipment: String?

    // MARK: - Derived filter vocabularies (kept in sync with the data)

    private var muscles: [String] {
        Array(Set(exercises.flatMap { $0.primaryMuscles })).sorted()
    }

    private var equipment: [String] {
        Array(Set(exercises.compactMap { $0.equipment })).sorted()
    }

    private var filtered: [Exercise] {
        exercises.filter { ex in
            let muscleOK = selectedMuscle.map {
                ex.primaryMuscles.contains($0) || ex.secondaryMuscles.contains($0)
            } ?? true
            let equipmentOK = selectedEquipment.map { ex.equipment == $0 } ?? true
            let searchOK = searchText.isEmpty
                || ex.name.localizedCaseInsensitiveContains(searchText)
            return muscleOK && equipmentOK && searchOK
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DS.Spacing.md, pinnedViews: [.sectionHeaders]) {
                Section {
                    if filtered.isEmpty {
                        emptyResults
                    } else {
                        ForEach(filtered) { exercise in
                            NavigationLink {
                                ExerciseDetailView(exercise: exercise)
                            } label: {
                                ExerciseRow(exercise: exercise)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    filterBar
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xxxl)
        }
        .background(GymBackground().ignoresSafeArea())
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search 1000+ exercises"
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { equipmentMenu }
        }
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        VStack(spacing: DS.Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    FilterChip(title: "All", isOn: selectedMuscle == nil) {
                        selectedMuscle = nil
                    }
                    ForEach(muscles, id: \.self) { muscle in
                        FilterChip(title: muscle.capitalized, isOn: selectedMuscle == muscle) {
                            selectedMuscle = (selectedMuscle == muscle) ? nil : muscle
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.xxs)
            }

            HStack {
                Text("^[\(filtered.count) exercise](inflect: true)")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if selectedEquipment != nil || selectedMuscle != nil {
                    Button("Clear filters") {
                        selectedMuscle = nil
                        selectedEquipment = nil
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DS.Palette.accent)
                }
            }
        }
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Palette.background.opacity(0.96))
    }

    private var equipmentMenu: some View {
        Menu {
            Button {
                selectedEquipment = nil
            } label: {
                Label("All equipment", systemImage: selectedEquipment == nil ? "checkmark" : "")
            }
            ForEach(equipment, id: \.self) { item in
                Button {
                    selectedEquipment = (selectedEquipment == item) ? nil : item
                } label: {
                    Label(item.capitalized, systemImage: selectedEquipment == item ? "checkmark" : "")
                }
            }
        } label: {
            Image(systemName: selectedEquipment == nil
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
                .foregroundStyle(DS.Palette.accent)
        }
    }

    private var emptyResults: some View {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "No matches",
            message: "Try a different muscle, equipment, or search term."
        )
        .padding(.top, DS.Spacing.xxxl)
    }
}

// MARK: - Row

private struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: DS.Spacing.lg) {
            Image(systemName: DS.Muscle.symbol(for: exercise.primaryMuscles.first ?? ""))
                .font(.title3.weight(.semibold))
                .foregroundStyle(DS.Muscle.color(for: exercise.primaryMuscles.first ?? ""))
                .frame(width: 44, height: 44)
                .background(
                    DS.Muscle.color(for: exercise.primaryMuscles.first ?? "").opacity(0.14),
                    in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                )

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(exercise.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: DS.Spacing.xs) {
                    Text(exercise.muscleSummary.isEmpty ? exercise.category.capitalized : exercise.muscleSummary)
                    if let equipment = exercise.equipment {
                        Text("· \(equipment.capitalized)")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(DS.Spacing.lg)
        .background(DS.Palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(DS.Palette.hairline, lineWidth: 1)
        )
    }
}

// MARK: - Filter chip

private struct FilterChip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(
                    isOn ? AnyShapeStyle(DS.Palette.accentGradient)
                         : AnyShapeStyle(DS.Palette.surfaceElevated),
                    in: Capsule()
                )
                .foregroundStyle(isOn ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }
}
