import SwiftUI

/// Resolves a machine (by name keywords) to its artwork: a generated,
/// muscle-group-coloured equipment icon asset (`mach-*`) for the thumbnail,
/// plus an Apple SF Symbol as a fallback when no asset matches.
enum MachineArt {
    private struct Rule { let keywords: [String]; let asset: String; let symbol: String }

    /// Order matters: specific names ("leg press") precede broader ones ("press").
    private static let rules: [Rule] = [
        Rule(keywords: ["chest press", "bench press", "incline press"], asset: "mach-chest-press", symbol: "figure.strengthtraining.traditional"),
        Rule(keywords: ["pec", "fly", "butterfly"], asset: "mach-pec-fly", symbol: "figure.arms.open"),
        Rule(keywords: ["pulldown", "pull-down", "lat "], asset: "mach-pulldown", symbol: "figure.gymnastics"),
        Rule(keywords: ["row"], asset: "mach-row", symbol: "figure.rower"),
        Rule(keywords: ["leg press"], asset: "mach-leg-press", symbol: "figure.strengthtraining.functional"),
        Rule(keywords: ["leg extension", "extension", "quad", "leg curl", "hamstring"], asset: "mach-leg-extension", symbol: "figure.seated.side"),
        Rule(keywords: ["shoulder", "overhead"], asset: "mach-shoulder-press", symbol: "dumbbell.fill"),
        Rule(keywords: ["tricep"], asset: "mach-triceps", symbol: "figure.boxing"),
        Rule(keywords: ["bicep", "curl"], asset: "mach-biceps-curl", symbol: "figure.cooldown"),
        Rule(keywords: ["dip"], asset: "mach-dip", symbol: "figure.climbing"),
        Rule(keywords: ["abdominal", "abs", "crunch", "core"], asset: "mach-abs", symbol: "figure.core.training"),
        Rule(keywords: ["torso", "rotation", "oblique", "rotary"], asset: "mach-torso-rotation", symbol: "figure.flexibility"),
    ]

    private static func rule(for machineName: String) -> Rule? {
        let name = machineName.lowercased()
        return rules.first { rule in rule.keywords.contains { name.contains($0) } }
    }

    /// Generated equipment-icon asset name, or nil if none matches.
    static func assetName(for machineName: String) -> String? { rule(for: machineName)?.asset }

    /// SF Symbol fallback, or nil if none matches.
    static func symbol(for machineName: String) -> String? { rule(for: machineName)?.symbol }
}

/// A machine's thumbnail: the user's photo if set, otherwise the generated
/// muscle-group equipment icon, otherwise an SF Symbol on the muscle-tinted
/// tile. Centralised so every surface renders machines identically.
struct MachineThumbnail: View {
    let name: String
    let imageData: Data?
    let muscleColor: Color
    let muscleSymbol: String
    var symbolSize: CGFloat = 42
    var cornerRadius: CGFloat = DS.Radius.sm

    var body: some View {
        Group {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let asset = MachineArt.assetName(for: name) {
                Image(asset)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [muscleColor.opacity(0.5), muscleColor.opacity(0.22)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    Image(systemName: muscleSymbol)
                        .font(.system(size: symbolSize, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
