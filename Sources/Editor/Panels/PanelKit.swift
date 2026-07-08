import SwiftUI

// Shared building blocks for the tool panels — a consistent visual language.

/// A slider that reports editing start/stop so panels can wrap a single undo
/// checkpoint around a drag while updating the model live in between.
struct EditSlider: View {
    let title: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var onEditing: (Bool) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.inkSecondary)
            Slider(value: $value, in: range) { editing in onEditing(editing) }
                .tint(Theme.accent)
        }
    }
}

/// A pill chip with optional icon; used for frame kinds, shadow presets, etc.
struct PanelChip: View {
    let title: String
    var systemImage: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 13, weight: .semibold)) }
                Text(title).font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(selected ? .white : Theme.ink)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(selected ? Theme.accent : Theme.surfaceSunk, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// A circular icon-tool button used to trigger create modes.
struct AddToolButton: View {
    let title: String
    let systemImage: String
    var active: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(active ? .white : Theme.accent)
                    .frame(width: 50, height: 50)
                    .background(active ? Theme.accent : Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.inkSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

/// A small color dot for choosing annotation/text colors.
struct ColorDot: View {
    let color: RGBAColor
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color.color)
                .frame(width: 28, height: 28)
                .overlay(Circle().stroke(.white, lineWidth: selected ? 3 : 0))
                .overlay(Circle().stroke(Theme.separator, lineWidth: 1))
                .shadow(color: .black.opacity(selected ? 0.2 : 0), radius: 2)
        }
        .buttonStyle(.plain)
    }
}

/// Standard palette for annotations / text.
enum ToolPalette {
    static let colors: [RGBAColor] = [
        RGBAColor(hex: "#FF3B30")!, RGBAColor(hex: "#FF9500")!, RGBAColor(hex: "#FFCC00")!,
        RGBAColor(hex: "#34C759")!, RGBAColor(hex: "#007AFF")!, RGBAColor(hex: "#5856D6")!,
        RGBAColor(hex: "#AF52DE")!, RGBAColor(hex: "#FF2D92")!, .white, .black,
    ]
}

/// A SwiftUI preview of a background style (for swatches). Approximates the CG
/// render; mesh/gradient match exactly.
struct BackgroundStylePreview: View {
    let style: BackgroundStyle

    var body: some View {
        switch style {
        case .solid(let c):
            Rectangle().fill(c.color)
        case .linearGradient(let colors, let angle):
            LinearGradient(colors: colors.map(\.color),
                           startPoint: unitPoint(angle + 180), endPoint: unitPoint(angle))
        case .radialGradient(let colors):
            RadialGradient(colors: colors.map(\.color), center: .center, startRadius: 0, endRadius: 40)
        case .mesh(let spec):
            MeshBackground(spec: spec)
        case .image:
            Rectangle().fill(Theme.surfaceSunk).overlay(Image(systemName: "photo").foregroundStyle(Theme.inkTertiary))
        case .blurredScreenshot:
            LinearGradient(colors: [.gray, .gray.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                .overlay(Image(systemName: "drop.fill").foregroundStyle(.white.opacity(0.8)))
        case .pattern(_, let fg, let bg):
            Rectangle().fill(bg.color)
                .overlay(Image(systemName: "circle.grid.2x2.fill").font(.system(size: 16)).foregroundStyle(fg.color.opacity(0.7)))
        }
    }

    private func unitPoint(_ degrees: Double) -> UnitPoint {
        let r = degrees * .pi / 180
        return UnitPoint(x: 0.5 + cos(r) * 0.5, y: 0.5 + sin(r) * 0.5)
    }
}

/// Placeholder for tools whose panel isn't wired yet.
struct ComingSoonPanel: View {
    let tool: EditorTool
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: tool.symbol).font(.system(size: 22)).foregroundStyle(Theme.inkTertiary)
            Text("\(tool.title) coming up").font(.system(size: 13)).foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
