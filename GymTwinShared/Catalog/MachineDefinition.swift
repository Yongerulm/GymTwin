import Foundation

/// A canonical machine definition from the equipment library (the `machines`
/// repository / OpenSearch index). This is reference data — distinct from the
/// user's personal `Machine` (which holds their settings + photo). A scanned
/// QR/NFC `machineCode` resolves to one of these, which can then be linked to
/// or used to create a personal `Machine`.
///
/// `Sendable` + `Codable` value type so it crosses isolation boundaries and
/// maps cleanly to both the bundled JSON and the OpenSearch document.
struct MachineDefinition: Codable, Identifiable, Hashable, Sendable {
    /// Stable identifier scanned from QR/NFC, e.g. "sscp". Also the document id.
    let machineCode: String
    let name: String
    var manufacturer: String?
    let category: String
    var movementPattern: String?
    var primaryMuscles: [String]
    var secondaryMuscles: [String]
    var difficulty: String?
    var equipmentType: String?

    var id: String { machineCode }

    init(
        machineCode: String,
        name: String,
        manufacturer: String? = nil,
        category: String,
        movementPattern: String? = nil,
        primaryMuscles: [String] = [],
        secondaryMuscles: [String] = [],
        difficulty: String? = nil,
        equipmentType: String? = nil
    ) {
        self.machineCode = machineCode
        self.name = name
        self.manufacturer = manufacturer
        self.category = category
        self.movementPattern = movementPattern
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.difficulty = difficulty
        self.equipmentType = equipmentType
    }

    /// All muscles, primary first, for display and analytics grouping.
    var allMuscles: [String] { primaryMuscles + secondaryMuscles }

    /// A concise muscle summary, e.g. "Chest · Triceps".
    var muscleSummary: String {
        primaryMuscles.isEmpty ? category : primaryMuscles.joined(separator: " · ")
    }
}
