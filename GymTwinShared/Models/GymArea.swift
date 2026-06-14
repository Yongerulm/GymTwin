import Foundation
import SwiftData

/// A muscle group / zone within the gym, e.g. Chest, Back, Legs, Shoulders,
/// Arms, Core, Cardio. Owns the machines physically located in that area.
@Model
final class GymArea {
    @Attribute(.unique) var id: UUID
    var name: String
    var sortIndex: Int

    /// Owning gym. Plain back-reference; the cascade rule lives on `Gym.areas`.
    var gym: Gym?

    @Relationship(deleteRule: .cascade, inverse: \Machine.area)
    var machines: [Machine]

    init(
        id: UUID = UUID(),
        name: String,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.sortIndex = sortIndex
        self.machines = []
    }

    /// Machines in their user-defined display order.
    var sortedMachines: [Machine] {
        machines.sorted { $0.sortIndex < $1.sortIndex }
    }
}
