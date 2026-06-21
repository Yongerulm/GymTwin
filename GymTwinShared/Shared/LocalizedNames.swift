import Foundation

/// Display-time German translations for data that lives in the store as English
/// (exercise + machine names). English stays canonical in SwiftData; this only
/// affects what the user sees. The active language follows the app's resolved
/// language (set via the in-app language switch / `AppleLanguages`).
enum LocalizedNames {

    /// Whether the app should currently show German names.
    static var isGerman: Bool {
        let lang = (UserDefaults.standard.array(forKey: "AppleLanguages")?.first as? String)
            ?? Locale.preferredLanguages.first
            ?? "en"
        return lang.hasPrefix("de")
    }

    /// Localized exercise name (falls back to English when no translation).
    static func exerciseName(_ english: String) -> String {
        guard isGerman else { return english }
        return exerciseDE[english] ?? english
    }

    /// Localized machine name.
    static func machineName(_ english: String) -> String {
        guard isGerman else { return english }
        return machineDE[english] ?? english
    }

    /// Localized muscle-group / area label (small finite vocabulary).
    static func muscle(_ english: String) -> String {
        guard isGerman else { return english }
        return muscleDE[english.lowercased()] ?? english
    }

    /// Localized machine-setting label (e.g. "Seat Height" → "Sitzhöhe").
    static func setting(_ english: String) -> String {
        guard isGerman else { return english }
        return settingDE[english.lowercased()] ?? english
    }

    /// Localized exercise metadata (equipment / category / level / mechanic /
    /// force / muscle), all from one small vocabulary.
    static func term(_ english: String) -> String {
        guard isGerman, !english.isEmpty else { return english }
        let key = english.lowercased()
        return termDE[key] ?? muscleDE[key] ?? english
    }

    // MARK: - Bundled exercise dictionary (generated, en → de)

    private static let exerciseDE: [String: String] = loadJSON("exercise_names_de")

    private static func loadJSON(_ name: String) -> [String: String] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return dict
    }

    // MARK: - Machines (the gym's 15 machines)

    private static let machineDE: [String: String] = [
        "Chest Press": "Brustpresse",
        "Pectoral Fly": "Butterfly",
        "Pulldown": "Latzug",
        "Assist Dip": "Dip-Maschine (unterstützt)",
        "Biceps Curl": "Bizeps-Curl",
        "Triceps Press": "Trizepsdrücken",
        "Abdominal": "Bauchmaschine",
        "Torso Rotation": "Rumpfrotation",
        "Leg Extension": "Beinstrecker",
        "Leg Curl": "Beinbeuger",
        "Seated Leg Press": "Beinpresse (sitzend)",
        "Shoulder Press": "Schulterpresse",
        "Assist Chin": "Klimmzug-Maschine (unterstützt)",
        "Hip Abductor": "Abduktoren-Maschine",
        "Hip Adductor": "Adduktoren-Maschine",
        // SRC gym seed (SampleData) — the names actually shown in plans/sessions.
        "Pec Deck": "Butterfly",
        "Lat Pulldown": "Latzug",
        "Seated Row": "Sitzrudern",
        "Leg Press": "Beinpresse",
        "Bicep Curl": "Bizeps-Curl",
        "Triceps Pushdown": "Trizeps-Drücken",
    ]

    // MARK: - Machine settings (SampleData)

    private static let settingDE: [String: String] = [
        "seat height": "Sitzhöhe",
        "back position": "Rückenposition",
        "back angle": "Rückenlehne",
        "handle position": "Griffposition",
        "handle width": "Griffbreite",
        "range": "Bewegungsbereich",
        "knee pad": "Kniepolster",
        "chest pad": "Brustpolster",
        "seat position": "Sitzposition",
        "seat depth": "Sitztiefe",
        "ankle pad": "Fußpolster",
        "arm pad": "Armpolster",
        "cable height": "Kabelhöhe",
        "weight": "Gewicht",
        "level": "Stufe",
        "incline": "Neigung",
    ]

    // MARK: - Exercise metadata (equipment / category / level / mechanic / force)

    private static let termDE: [String: String] = [
        // equipment
        "body only": "Eigengewicht",
        "barbell": "Langhantel",
        "dumbbell": "Kurzhantel",
        "kettlebells": "Kettlebells",
        "cable": "Kabelzug",
        "machine": "Maschine",
        "bands": "Bänder",
        "medicine ball": "Medizinball",
        "exercise ball": "Gymnastikball",
        "foam roll": "Faszienrolle",
        "e-z curl bar": "SZ-Stange",
        "other": "Sonstiges",
        // category
        "strength": "Kraft",
        "stretching": "Dehnen",
        "plyometrics": "Plyometrie",
        "strongman": "Strongman",
        "powerlifting": "Powerlifting",
        "cardio": "Cardio",
        "olympic weightlifting": "Olympisches Gewichtheben",
        // level
        "beginner": "Anfänger",
        "intermediate": "Fortgeschritten",
        "expert": "Experte",
        // mechanic
        "compound": "Mehrgelenkig",
        "isolation": "Isolation",
        // force
        "push": "Drücken",
        "pull": "Ziehen",
        "static": "Statisch",
    ]

    // MARK: - Muscle groups / areas

    private static let muscleDE: [String: String] = [
        "chest": "Brust",
        "back": "Rücken",
        "legs": "Beine",
        "leg": "Beine",
        "shoulders": "Schultern",
        "shoulder": "Schultern",
        "arms": "Arme",
        "arm": "Arme",
        "core": "Core",
        "abdominals": "Bauch",
        "cardio": "Cardio",
        "biceps": "Bizeps",
        "triceps": "Trizeps",
        "glutes": "Gesäß",
        "hamstrings": "Beinbeuger",
        "quadriceps": "Quadrizeps",
        "calves": "Waden",
        "lats": "Latissimus",
        "traps": "Trapez",
        "forearms": "Unterarme",
    ]
}
