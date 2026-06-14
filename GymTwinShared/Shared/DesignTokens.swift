import SwiftUI

/// Cross-platform design tokens. Numbers and colours only — no view code —
/// so the file compiles cleanly on both iOS and watchOS. The iOS component
/// library builds richer surfaces on top of these.
///
/// Visual language: calm, premium, Apple-Health-adjacent. Deep neutral
/// surfaces, one energetic electric-blue → violet accent, and a small set of
/// semantic colours used sparingly and meaningfully.
enum DS {
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
        static let xl: CGFloat = 28
        static let pill: CGFloat = 999
    }

    /// Brand + semantic palette. The accent is an energetic electric-blue →
    /// violet pair, used for primary actions and progress. Semantic colours
    /// (heart, energy, record, rest) each carry a single, consistent meaning.
    enum Palette {
        static let accent = Color(red: 0.30, green: 0.46, blue: 0.98)
        static let accentSecondary = Color(red: 0.55, green: 0.36, blue: 0.96)

        // MARK: Dark surfaces (the app is locked to a deep, premium dark theme
        // that matches the energetic gym imagery — deep anthracite base with
        // subtly blue-tinted, elevated card surfaces).
        /// App base background — deep anthracite (#0E0F14), not pure black.
        static let background = Color(red: 0.055, green: 0.060, blue: 0.078)
        /// Elevated card / surface fill — slightly blue-tinted dark (#181A22).
        static let surface = Color(red: 0.094, green: 0.102, blue: 0.133)
        /// Higher-elevation surface for nested chips / sheets (#20232E).
        static let surfaceElevated = Color(red: 0.125, green: 0.137, blue: 0.180)
        /// Hairline separators / card borders on dark.
        static let hairline = Color.white.opacity(0.08)
        static let success = Color(red: 0.20, green: 0.78, blue: 0.52)
        static let record = Color(red: 0.99, green: 0.74, blue: 0.20)
        static let heart = Color(red: 0.98, green: 0.30, blue: 0.42)
        static let energy = Color(red: 0.99, green: 0.55, blue: 0.20)
        static let rest = Color(red: 0.22, green: 0.74, blue: 0.82)
        static let warning = Color(red: 0.98, green: 0.66, blue: 0.20)

        static var accentGradient: LinearGradient {
            LinearGradient(colors: [accent, accentSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        static var recordGradient: LinearGradient {
            LinearGradient(colors: [record, energy], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        static var heartGradient: LinearGradient {
            LinearGradient(colors: [heart, accentSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        /// A soft radial "halo" used behind hero content for premium depth.
        static var heroHalo: RadialGradient {
            RadialGradient(
                colors: [accent.opacity(0.22), accentSecondary.opacity(0.05), .clear],
                center: .topLeading, startRadius: 0, endRadius: 380
            )
        }
    }

    /// Stable colour + symbol per gym area / muscle group, for the Gym and
    /// Progress tabs. Falls back to the brand accent for unknown areas.
    enum Muscle {
        static func color(for area: String) -> Color {
            switch area.lowercased() {
            case let a where a.contains("chest"): return Color(red: 0.95, green: 0.39, blue: 0.45)
            case let a where a.contains("back"): return Color(red: 0.34, green: 0.55, blue: 0.96)
            case let a where a.contains("leg"): return Color(red: 0.42, green: 0.78, blue: 0.52)
            case let a where a.contains("shoulder"): return Color(red: 0.98, green: 0.62, blue: 0.27)
            case let a where a.contains("arm"): return Color(red: 0.66, green: 0.45, blue: 0.96)
            case let a where a.contains("core"): return Color(red: 0.30, green: 0.74, blue: 0.80)
            case let a where a.contains("cardio"): return Color(red: 0.98, green: 0.42, blue: 0.62)
            default: return Palette.accent
            }
        }

        /// Asset-catalog image name for an area's energetic hero photo
        /// (e.g. "area-chest"), or nil for an unknown area.
        static func imageName(for area: String) -> String? {
            switch area.lowercased() {
            case let a where a.contains("chest"): return "area-chest"
            case let a where a.contains("back"): return "area-back"
            case let a where a.contains("leg"): return "area-legs"
            case let a where a.contains("shoulder"): return "area-shoulders"
            case let a where a.contains("arm"): return "area-arms"
            case let a where a.contains("core"): return "area-core"
            case let a where a.contains("cardio"): return "area-cardio"
            default: return nil
            }
        }

        static func symbol(for area: String) -> String {
            switch area.lowercased() {
            case let a where a.contains("chest"): return "figure.strengthtraining.traditional"
            case let a where a.contains("back"): return "figure.rower"
            case let a where a.contains("leg"): return "figure.run"
            case let a where a.contains("shoulder"): return "figure.arms.open"
            case let a where a.contains("arm"): return "dumbbell.fill"
            case let a where a.contains("core"): return "figure.core.training"
            case let a where a.contains("cardio"): return "heart.fill"
            default: return "dumbbell.fill"
            }
        }
    }

    /// Standard springs used across the app for a consistent, calm motion feel.
    enum Motion {
        static let spring = Animation.spring(response: 0.35, dampingFraction: 0.78)
        static let snappy = Animation.spring(response: 0.28, dampingFraction: 0.7)
    }
}
