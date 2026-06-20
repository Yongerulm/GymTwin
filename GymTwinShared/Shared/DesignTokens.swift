import SwiftUI

// MARK: - Color(hex:)

extension Color {
    /// Hex initialiser (`"#RRGGBB"` or `"RRGGBB"`), used by the Ember tokens so
    /// values can be lifted verbatim from the design handoff.
    init(hex: String) {
        let raw = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var value: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

/// Cross-platform design tokens. Numbers and colours only — no view code —
/// so the file compiles cleanly on both iOS and watchOS. The iOS component
/// library builds richer surfaces on top of these.
///
/// Visual language — **Ember**: deep warm-dark backgrounds, a single ember-orange
/// primary accent, and rich gradient-coloured body-area tiles. Semantic colours
/// (heart, record, rest) each carry a single, consistent meaning.
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
        static let md: CGFloat = 15
        static let lg: CGFloat = 20
        static let xl: CGFloat = 22
        static let pill: CGFloat = 999
    }

    /// Ember palette. The accent is an ember-orange pair used for primary
    /// actions and progress; warm-dark neutral surfaces sit beneath.
    enum Palette {
        static let accent = Color(hex: "#FF6B2C")
        /// Gradient end / deep ember, paired with `accent`.
        static let accentSecondary = Color(hex: "#E04400")

        // MARK: Warm-dark surfaces (the app is locked to a deep, premium dark
        // theme — near-black warm base with subtly warm elevated card surfaces).
        /// App base background — deep warm near-black (#0A0806).
        static let background = Color(hex: "#0A0806")
        /// Elevated card / surface fill — warm dark (#181512).
        static let surface = Color(hex: "#181512")
        /// Higher-elevation surface for chips / nav / sheets (#1E1A14).
        static let surfaceElevated = Color(hex: "#1E1A14")
        /// Hairline separators / card borders on dark.
        static let hairline = Color.white.opacity(0.06)

        // MARK: Text (warm off-white ramp)
        static let textPrimary = Color(hex: "#F5F0EA")
        static let textSecondary = Color(hex: "#F5F0EA").opacity(0.55)
        static let textTertiary = Color(hex: "#F5F0EA").opacity(0.28)

        // MARK: Semantic (Ember-aligned)
        static let success = Color(hex: "#28A85E")
        static let record = Color(hex: "#E07A32")
        static let heart = Color(hex: "#D94F63")
        static let energy = Color(hex: "#FF7A40")
        static let rest = Color(hex: "#3DA8B8")
        static let warning = Color(hex: "#E07A32")

        static var accentGradient: LinearGradient {
            LinearGradient(
                colors: [Color(hex: "#FF7A40"), Color(hex: "#E04400")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        static var recordGradient: LinearGradient {
            LinearGradient(colors: [record, energy], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        static var heartGradient: LinearGradient {
            LinearGradient(colors: [heart, accentSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        /// A soft warm radial "halo" used behind hero content for premium depth.
        static var heroHalo: RadialGradient {
            RadialGradient(
                colors: [accent.opacity(0.22), accent.opacity(0.05), .clear],
                center: .topLeading, startRadius: 0, endRadius: 380
            )
        }
    }

    /// Stable colour + gradient + symbol per gym area / muscle group, for the
    /// Gym and Progress tabs. Falls back to the brand accent for unknown areas.
    enum Muscle {
        /// Primary (start) colour per area — used for bars, accents, icon tints.
        static func color(for area: String) -> Color {
            gradientColors(for: area).start
        }

        /// Ember gradient stops per body area (start = lighter, end = deeper),
        /// lifted from the design handoff.
        static func gradientColors(for area: String) -> (start: Color, end: Color) {
            switch area.lowercased() {
            case let a where a.contains("chest"): return (Color(hex: "#D94F63"), Color(hex: "#9A2040"))
            case let a where a.contains("back"): return (Color(hex: "#3D6FE8"), Color(hex: "#1C3CB0"))
            case let a where a.contains("leg"): return (Color(hex: "#28A85E"), Color(hex: "#146838"))
            case let a where a.contains("shoulder"): return (Color(hex: "#E07A32"), Color(hex: "#A04A10"))
            case let a where a.contains("arm"): return (Color(hex: "#9048E0"), Color(hex: "#5A1CAC"))
            case let a where a.contains("core"): return (Color(hex: "#B8902A"), Color(hex: "#7A5A08"))
            case let a where a.contains("cardio"): return (Color(hex: "#FF6B2C"), Color(hex: "#B42C00"))
            default: return (Palette.accent, Palette.accentSecondary)
            }
        }

        /// Diagonal area gradient for tiles, chips and hero cards.
        static func gradient(for area: String) -> LinearGradient {
            let c = gradientColors(for: area)
            return LinearGradient(colors: [c.start, c.end], startPoint: .topLeading, endPoint: .bottomTrailing)
        }

        /// Soft glow colour (the area's start colour) for tile shadows.
        static func glow(for area: String) -> Color { gradientColors(for: area).start }

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
