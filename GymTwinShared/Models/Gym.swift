import Foundation
import SwiftData

/// The single gym this app is a digital twin of. The architecture allows
/// multiple `Gym` rows for a possible future multi-gym mode, but the app
/// seeds and operates on exactly one gym today.
@Model
final class Gym {
    @Attribute(.unique) var id: UUID
    var name: String
    var location: String
    var createdDate: Date

    /// Areas of the gym (Chest, Back, Legs, …). Deleting a gym removes its
    /// areas, and cascades on to their machines.
    @Relationship(deleteRule: .cascade, inverse: \GymArea.gym)
    var areas: [GymArea]

    init(
        id: UUID = UUID(),
        name: String,
        location: String = "",
        createdDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.createdDate = createdDate
        self.areas = []
    }

    /// Areas in their user-defined display order.
    var sortedAreas: [GymArea] {
        areas.sorted { $0.sortIndex < $1.sortIndex }
    }
}
