import SwiftUI

/// Resolves a machine to a schematic equipment icon (asset-catalog image),
/// matched by keywords in its name. Returns `nil` when no specific icon fits,
/// so call sites fall back to the muscle-group SF Symbol.
enum MachineArt {
    /// Ordered keyword → asset rules. Order matters: more specific names
    /// (e.g. "leg press") must be checked before broader ones ("press").
    private static let rules: [(keywords: [String], asset: String)] = [
        (["chest press", "bench press", "incline press"], "micon-chest-press"),
        (["pec", "fly", "butterfly"], "micon-pec-fly"),
        (["pulldown", "pull-down", "lat "], "micon-pulldown"),
        (["row"], "micon-row"),
        (["leg press"], "micon-leg-press"),
        (["leg extension", "extension", "quad"], "micon-leg-extension"),
        (["shoulder", "overhead"], "micon-shoulder-press"),
        (["tricep"], "micon-triceps"),
        (["bicep", "curl"], "micon-biceps-curl"),
        (["dip"], "micon-dip"),
        (["abdominal", "abs", "crunch", "core"], "micon-abs"),
        (["torso", "rotation", "oblique", "rotary"], "micon-torso-rotation"),
    ]

    /// The schematic icon asset name for a machine, or `nil` if none matches.
    static func iconName(for machineName: String) -> String? {
        let name = machineName.lowercased()
        for rule in rules where rule.keywords.contains(where: { name.contains($0) }) {
            return rule.asset
        }
        return nil
    }
}

/// A machine's thumbnail artwork: the user's photo if set, otherwise a
/// schematic equipment icon, otherwise the muscle-group SF Symbol — all on the
/// muscle-tinted tile. Centralised so every surface renders machines identically.
struct MachineThumbnail: View {
    let name: String
    let imageData: Data?
    let muscleColor: Color
    let muscleSymbol: String
    var cornerRadius: CGFloat = DS.Radius.sm

    var body: some View {
        ZStack {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [muscleColor.opacity(0.45), muscleColor.opacity(0.18)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                if let icon = MachineArt.iconName(for: name) {
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                } else {
                    Image(systemName: muscleSymbol)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
