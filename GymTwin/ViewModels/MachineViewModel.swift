import Foundation
import SwiftData

/// View model for all machine and setting CRUD operations. Exposes the current
/// list of areas so pickers in edit sheets stay in sync without a separate
/// `GymViewModel` dependency.
@Observable @MainActor
final class MachineViewModel {

    // MARK: - State

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
        areas = storage.fetchAll(
            GymArea.self,
            sortBy: [SortDescriptor(\.sortIndex)]
        )
    }

    // MARK: - Machine mutations

    /// Creates and inserts a new machine, optionally linking it to an area.
    @discardableResult
    func addMachine(
        name: String,
        category: String = "",
        area: GymArea? = nil,
        notes: String = "",
        imageData: Data? = nil
    ) -> Machine? {
        guard let context else { return nil }
        let nextIndex: Int
        if let area {
            nextIndex = (area.machines.map(\.sortIndex).max() ?? -1) + 1
        } else {
            let storage = StorageService(context: context)
            nextIndex = storage.count(Machine.self)
        }
        let machine = Machine(
            name: name,
            category: category,
            notes: notes,
            imageData: imageData,
            sortIndex: nextIndex
        )
        if let area {
            machine.area = area
            area.machines.append(machine)
        }
        context.insert(machine)
        try? context.save()
        refresh()
        return machine
    }

    /// Updates mutable fields on an existing machine.
    func updateMachine(
        _ machine: Machine,
        name: String,
        category: String,
        area: GymArea?,
        notes: String,
        imageData: Data?
    ) {
        guard let context else { return }
        machine.name = name
        machine.category = category
        machine.notes = notes
        machine.imageData = imageData
        assignArea(area, to: machine)
        try? context.save()
        refresh()
    }

    /// Removes a machine from the store (cascade deletes its settings).
    func deleteMachine(_ machine: Machine) {
        guard let context else { return }
        context.delete(machine)
        try? context.save()
        refresh()
    }

    // MARK: - Area assignment

    /// Moves a machine to a different area (or removes it from its current area).
    func assignArea(_ area: GymArea?, to machine: Machine) {
        guard let context else { return }
        if let old = machine.area {
            old.machines.removeAll { $0.id == machine.id }
        }
        machine.area = area
        if let area, !area.machines.contains(where: { $0.id == machine.id }) {
            area.machines.append(machine)
        }
        try? context.save()
        refresh()
    }

    // MARK: - Setting mutations

    /// Adds a new setting to a machine.
    @discardableResult
    func addSetting(title: String, value: String = "", to machine: Machine) -> MachineSetting? {
        guard let context else { return nil }
        let nextIndex = (machine.settings.map(\.sortIndex).max() ?? -1) + 1
        let setting = MachineSetting(title: title, value: value, sortIndex: nextIndex)
        setting.machine = machine
        machine.settings.append(setting)
        context.insert(setting)
        try? context.save()
        return setting
    }

    /// Removes a setting from a machine.
    func removeSetting(_ setting: MachineSetting, from machine: Machine) {
        guard let context else { return }
        machine.settings.removeAll { $0.id == setting.id }
        context.delete(setting)
        try? context.save()
    }

    /// Reorders settings by applying new sortIndex values matching the provided order.
    func reorderSettings(_ orderedSettings: [MachineSetting], for machine: Machine) {
        guard let context else { return }
        for (index, setting) in orderedSettings.enumerated() {
            setting.sortIndex = index
        }
        try? context.save()
    }

    // MARK: - Area helpers

    /// Adds a named area to the single gym. Falls back gracefully if no gym exists.
    @discardableResult
    func addArea(name: String) -> GymArea? {
        guard let context else { return nil }
        let storage = StorageService(context: context)
        let gyms = storage.fetchAll(Gym.self)
        let gym = gyms.first
        let nextIndex = (areas.map(\.sortIndex).max() ?? -1) + 1
        let area = GymArea(name: name, sortIndex: nextIndex)
        area.gym = gym
        gym?.areas.append(area)
        context.insert(area)
        try? context.save()
        refresh()
        return area
    }
}
