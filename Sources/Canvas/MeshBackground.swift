import SwiftUI

/// SwiftUI view for an iOS-18 `MeshGradient` built from a `MeshSpec`. Used both
/// for live preview and (via `ImageRenderer`) rasterized into exports so the
/// two always match.
struct MeshBackground: View {
    let spec: MeshSpec

    var body: some View {
        MeshGradient(width: spec.cols, height: spec.rows, points: points, colors: colors)
    }

    private var points: [SIMD2<Float>] {
        var result: [SIMD2<Float>] = []
        let cols = max(spec.cols, 2), rows = max(spec.rows, 2)
        for r in 0..<rows {
            for c in 0..<cols {
                result.append(SIMD2(Float(c) / Float(cols - 1), Float(r) / Float(rows - 1)))
            }
        }
        return result
    }

    private var colors: [Color] {
        let needed = spec.rows * spec.cols
        if spec.colors.count == needed { return spec.colors.map(\.color) }
        // Pad / trim defensively.
        var out = spec.colors.map(\.color)
        while out.count < needed { out.append(out.last ?? .purple) }
        return Array(out.prefix(needed))
    }
}
