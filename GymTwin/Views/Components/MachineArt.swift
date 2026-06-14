import SwiftUI

/// Resolves a machine to a professional Apple SF Symbol that depicts its
/// movement — Apple's own fitness glyphs (verified available on iOS 18), so
/// every machine reads cleanly and natively, distinct per type. Returns `nil`
/// when nothing fits, so callers fall back to the muscle-group symbol.
enum MachineArt {
    /// Ordered keyword → SF Symbol. Order matters: specific names ("leg press")
    /// must precede broader ones ("press").
    private static let rules: [(keywords: [String], symbol: String)] = [
        (["chest press", "bench press", "incline press"], "figure.strengthtraining.traditional"),
        (["pec", "fly", "butterfly"], "figure.arms.open"),
        (["pulldown", "pull-down", "lat "], "figure.gymnastics"),
        (["row"], "figure.rower"),
        (["leg press"], "figure.strengthtraining.functional"),
        (["leg extension", "extension", "quad", "leg curl", "hamstring"], "figure.seated.side"),
        (["shoulder", "overhead"], "dumbbell.fill"),
        (["tricep"], "figure.boxing"),
        (["bicep", "curl"], "figure.cooldown"),
        (["dip"], "figure.climbing"),
        (["abdominal", "abs", "crunch", "core"], "figure.core.training"),
        (["torso", "rotation", "oblique", "rotary"], "figure.flexibility"),
        (["treadmill", "run"], "figure.run"),
        (["bike", "cycle", "spin"], "figure.indoor.cycle"),
        (["elliptical", "cross trainer"], "figure.elliptical"),
        (["stair", "step"], "figure.stair.stepper"),
        (["cardio"], "figure.mixed.cardio"),
    ]

    /// The SF Symbol name for a machine, or `nil` if none matches.
    static func symbol(for machineName: String) -> String? {
        let name = machineName.lowercased()
        for rule in rules where rule.keywords.contains(where: { name.contains($0) }) {
            return rule.symbol
        }
        return nil
    }
}

/// A machine's thumbnail: the user's photo if set, otherwise a movement-specific
/// SF Symbol (falling back to the muscle-group symbol) on the muscle-tinted
/// tile. Centralised so every surface renders machines identically.
struct MachineThumbnail: View {
    let name: String
    let imageData: Data?
    let muscleColor: Color
    let muscleSymbol: String
    var symbolSize: CGFloat = 42
    var cornerRadius: CGFloat = DS.Radius.sm

    var body: some View {
        ZStack {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [muscleColor.opacity(0.5), muscleColor.opacity(0.22)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                Image(systemName: MachineArt.symbol(for: name) ?? muscleSymbol)
                    .font(.system(size: symbolSize, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.22), radius: 5, y: 2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
