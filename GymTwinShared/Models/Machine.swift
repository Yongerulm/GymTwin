import Foundation
import SwiftData

/// A single training machine (or piece of equipment). Holds the user's
/// personal, dynamic settings and an optional photo.
///
/// Workout history is intentionally NOT a stored relationship: a
/// `WorkoutExercise` references a machine by `machineID` + denormalized
/// `machineName`, so deleting a machine never destroys past performance data.
/// History is queried on demand via `WorkoutService`.
@Model
final class Machine {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String
    var notes: String
    /// Optional machine photo. Stored outside the main store to keep the
    /// database small. `nil` when the user has not added an image.
    @Attribute(.externalStorage) var imageData: Data?
    var createdDate: Date
    var sortIndex: Int

    /// Canonical equipment-library code (e.g. "sscp") scanned from QR/NFC.
    /// Links this personal machine to a `MachineDefinition`. `nil` for
    /// machines created manually without scanning.
    var machineCode: String?

    /// Owning area. Plain back-reference; cascade lives on `GymArea.machines`.
    var area: GymArea?

    /// The user's preferred settings for this machine (Seat Height, etc.).
    @Relationship(deleteRule: .cascade, inverse: \MachineSetting.machine)
    var settings: [MachineSetting]

    init(
        id: UUID = UUID(),
        name: String,
        category: String = "",
        notes: String = "",
        imageData: Data? = nil,
        createdDate: Date = Date(),
        sortIndex: Int = 0,
        machineCode: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.notes = notes
        self.imageData = imageData
        self.createdDate = createdDate
        self.sortIndex = sortIndex
        self.machineCode = machineCode
        self.settings = []
    }

    /// Settings in their user-defined display order.
    var sortedSettings: [MachineSetting] {
        settings.sorted { $0.sortIndex < $1.sortIndex }
    }
}
