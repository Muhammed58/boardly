import Foundation

/// Curated backdrop catalog shown in the Background panel — the "make it
/// pretty" palette (solid, gradient, and iOS-18 mesh options).
enum BackgroundPresets {

    private static func hex(_ s: String) -> RGBAColor { RGBAColor(hex: s) ?? .black }

    static let defaultBackground = BackgroundPreset(
        id: "violet-dream", name: "Violet",
        style: .linearGradient(colors: [hex("#6D5EF3"), hex("#A66BF0"), hex("#F178B6")], angle: 135)
    )

    static let solids: [BackgroundPreset] = [
        BackgroundPreset(id: "white", name: "White", style: .solid(hex("#FFFFFF"))),
        BackgroundPreset(id: "snow", name: "Snow", style: .solid(hex("#F4F5F7"))),
        BackgroundPreset(id: "graphite", name: "Graphite", style: .solid(hex("#1C1C1E"))),
        BackgroundPreset(id: "ink", name: "Ink", style: .solid(hex("#0B1020"))),
        BackgroundPreset(id: "sky", name: "Sky", style: .solid(hex("#DCEBFF"))),
        BackgroundPreset(id: "mint", name: "Mint", style: .solid(hex("#D6F5E3"))),
        BackgroundPreset(id: "peach", name: "Peach", style: .solid(hex("#FFE3D3"))),
        BackgroundPreset(id: "lilac", name: "Lilac", style: .solid(hex("#EADCFF"))),
    ]

    static let gradients: [BackgroundPreset] = [
        BackgroundPreset(id: "violet-dream", name: "Violet", style: .linearGradient(colors: [hex("#6D5EF3"), hex("#A66BF0"), hex("#F178B6")], angle: 135)),
        BackgroundPreset(id: "sunset", name: "Sunset", style: .linearGradient(colors: [hex("#FF8A00"), hex("#FF3D77")], angle: 130)),
        BackgroundPreset(id: "ocean", name: "Ocean", style: .linearGradient(colors: [hex("#2AF598"), hex("#009EFD")], angle: 120)),
        BackgroundPreset(id: "candy", name: "Candy", style: .linearGradient(colors: [hex("#FCCB90"), hex("#D57EEB")], angle: 120)),
        BackgroundPreset(id: "grape", name: "Grape", style: .linearGradient(colors: [hex("#5B247A"), hex("#1BCEDF")], angle: 135)),
        BackgroundPreset(id: "flare", name: "Flare", style: .linearGradient(colors: [hex("#F12711"), hex("#F5AF19")], angle: 120)),
        BackgroundPreset(id: "night", name: "Night", style: .linearGradient(colors: [hex("#141E30"), hex("#243B55")], angle: 135)),
        BackgroundPreset(id: "royal", name: "Royal", style: .linearGradient(colors: [hex("#141E30"), hex("#7028E4")], angle: 130)),
        BackgroundPreset(id: "bloom", name: "Bloom", style: .linearGradient(colors: [hex("#F797FF"), hex("#7B6CFF"), hex("#4FC3FF")], angle: 140)),
        BackgroundPreset(id: "lime", name: "Lime", style: .linearGradient(colors: [hex("#B7F8DB"), hex("#50A7C2")], angle: 120)),
        BackgroundPreset(id: "coral", name: "Coral", style: .linearGradient(colors: [hex("#FF9A9E"), hex("#FAD0C4")], angle: 120)),
        BackgroundPreset(id: "slate", name: "Slate", style: .linearGradient(colors: [hex("#485563"), hex("#29323C")], angle: 135)),
    ]

    static let meshes: [BackgroundPreset] = [
        BackgroundPreset(id: "mesh-aurora", name: "Aurora", style: .mesh(MeshSpec(rows: 3, cols: 3, colors: [
            hex("#7A5CFF"), hex("#8E6BFF"), hex("#B36BFF"),
            hex("#5AC8FF"), hex("#8A7BFF"), hex("#E86BC5"),
            hex("#4FE0C6"), hex("#6CA8FF"), hex("#FF8AD0"),
        ]))),
        BackgroundPreset(id: "mesh-sunrise", name: "Sunrise", style: .mesh(MeshSpec(rows: 3, cols: 3, colors: [
            hex("#FF9A5A"), hex("#FF7EB3"), hex("#FF6A88"),
            hex("#FFC26F"), hex("#FF9A8B"), hex("#FF6A88"),
            hex("#FFE29F"), hex("#FFB88C"), hex("#F56A79"),
        ]))),
        BackgroundPreset(id: "mesh-lagoon", name: "Lagoon", style: .mesh(MeshSpec(rows: 3, cols: 3, colors: [
            hex("#00C6FB"), hex("#48D6C2"), hex("#5AF0B0"),
            hex("#2B8EFF"), hex("#38C6E0"), hex("#4DE2B0"),
            hex("#5B7CFF"), hex("#2FB0FF"), hex("#39E0C0"),
        ]))),
        BackgroundPreset(id: "mesh-berry", name: "Berry", style: .mesh(MeshSpec(rows: 3, cols: 3, colors: [
            hex("#8E2DE2"), hex("#C13AD6"), hex("#E84AC4"),
            hex("#6A11CB"), hex("#A83DDB"), hex("#F150A0"),
            hex("#4A0E9E"), hex("#8E2DE2"), hex("#E84A8A"),
        ]))),
    ]

    static let patterns: [BackgroundPreset] = [
        BackgroundPreset(id: "p-dots", name: "Dots", style: .pattern(.dots, hex("#B9C0FF"), hex("#EEF0FF"))),
        BackgroundPreset(id: "p-grid", name: "Grid", style: .pattern(.grid, hex("#C9CEDD"), hex("#F5F6F8"))),
        BackgroundPreset(id: "p-graph", name: "Graph", style: .pattern(.graph, hex("#CBD5E1"), hex("#FFFFFF"))),
        BackgroundPreset(id: "p-diag", name: "Diagonal", style: .pattern(.diagonal, hex("#D7B8FF"), hex("#F3ECFF"))),
        BackgroundPreset(id: "p-noise", name: "Noise", style: .pattern(.noise, hex("#8A8A93"), hex("#E8E8EC"))),
    ]

    static let all: [(String, [BackgroundPreset])] = [
        ("Gradients", gradients),
        ("Mesh", meshes),
        ("Pattern", patterns),
        ("Solid", solids),
    ]
}
