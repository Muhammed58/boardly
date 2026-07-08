import Foundation

/// The bottom-bar tools. Each drives a panel of controls and, where relevant,
/// a placement/drawing mode on the canvas.
enum EditorTool: String, CaseIterable, Identifiable {
    case styles
    case background
    case frame
    case text
    case annotate
    case redact
    case spotlight
    case sticker
    case crop
    case layers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .styles: return "Styles"
        case .background: return "Background"
        case .frame: return "Frame"
        case .text: return "Text"
        case .annotate: return "Draw"
        case .redact: return "Redact"
        case .spotlight: return "Spotlight"
        case .sticker: return "Sticker"
        case .crop: return "Crop"
        case .layers: return "Layers"
        }
    }

    var symbol: String {
        switch self {
        case .styles: return "wand.and.stars"
        case .background: return "paintpalette"
        case .frame: return "macwindow"
        case .text: return "textformat"
        case .annotate: return "pencil.tip.crop.circle"
        case .redact: return "eye.slash"
        case .spotlight: return "flashlight.on.fill"
        case .sticker: return "face.smiling"
        case .crop: return "crop"
        case .layers: return "square.3.layers.3d"
        }
    }
}
