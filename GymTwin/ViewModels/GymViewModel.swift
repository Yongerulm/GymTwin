import Foundation
import SwiftData

/// Manages the single `Gym` entity and its areas. Creates a default gym on
/// first launch if none exists. Area mutations are performed here so that
/// `MachineViewModel` can stay focused on machine-level concerns.
@Observable @MainActor
final class GymViewModel {

    // MARK: - State

    private(set) var gym: Gym?
    private(set) var areas: [GymArea] = []

    // MARK: - Internal

    private var context: ModelContext?

    // MARK: - Bind

    func bind(_ context: ModelContext) {
        self.context = context
        refresh()
    }

    // MARK: - Refresh

    func refresh() {
        guard let context else { return }
        let storage = StorageService(context: context)
        let gyms = storage.fetchAll(Gym.self)
        if let existing = gyms.first {
            gym = existing
        } else {
            let newGym = Gym(name: "My Gym")
            context.insert(newGym)
            try? context.save()
            gym = newGym
        }
        areas = gym?.sortedAreas ?? []
    }

    // MARK: - Area mutations

    /// Adds a new area to the gym. Returns the created area.
    @discardableResult
    func addArea(name: String) -> GymArea? {
        guard let context, let gym else { return nil }
        let nextIndex = (gym.areas.map(\.sortIndex).max() ?? -1) + 1
        let area = GymArea(name: name, sortIndex: nextIndex)
        area.gym = gym
        gym.areas.append(area)
        context.insert(area)
        try? context.save()
        refresh()
        return area
    }

    /// Renames an existing area.
    func renameArea(_ area: GymArea, to name: String) {
        guard let context else { return }
        area.name = name
        try? context.save()
        refresh()
    }

    /// Deletes an area and all its machines (cascade).
    func deleteArea(_ area: GymArea) {
        guard let context else { return }
        context.delete(area)
        try? context.save()
        refresh()
    }
}
