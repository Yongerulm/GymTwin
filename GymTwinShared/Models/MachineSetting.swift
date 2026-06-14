import Foundation
import SwiftData

/// A dynamic, user-defined machine setting. Each machine can have a completely
/// different set of settings, e.g. a Chest Press has "Seat Height",
/// "Back Position", "Handle Position" while a Cable machine has others.
///
/// `value` is stored as a `String` so it can hold non-numeric settings
/// ("6", "3 notches", "B") without losing information.
@Model
final class MachineSetting {
    @Attribute(.unique) var id: UUID
    var title: String
    var value: String
    var sortIndex: Int

    /// Owning machine. Plain back-reference; cascade lives on `Machine.settings`.
    var machine: Machine?

    init(
        id: UUID = UUID(),
        title: String,
        value: String = "",
        sortIndex: Int = 0
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.sortIndex = sortIndex
    }
}
