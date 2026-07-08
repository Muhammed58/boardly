import SwiftUI
import UIKit

/// A `Codable`, value-type color used throughout the model so projects can be
/// persisted and diffed. Bridges to SwiftUI `Color`, `UIColor`, and `CGColor`.
struct RGBAColor: Codable, Equatable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    // MARK: Bridging

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha) }

    var uiColor: UIColor { UIColor(red: red, green: green, blue: blue, alpha: alpha) }

    var cgColor: CGColor { uiColor.cgColor }

    init(_ color: Color) { self.init(UIColor(color)) }

    init(_ ui: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
    }

    func opacity(_ value: Double) -> RGBAColor {
        RGBAColor(red: red, green: green, blue: blue, alpha: value)
    }

    // MARK: Hex

    init?(hex raw: String) {
        var hex = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hex.hasPrefix("#") { hex.removeFirst() }
        if hex.count == 6 { hex += "FF" }
        guard hex.count == 8, let value = UInt64(hex, radix: 16) else { return nil }
        self.init(
            red: Double((value & 0xFF00_0000) >> 24) / 255,
            green: Double((value & 0x00FF_0000) >> 16) / 255,
            blue: Double((value & 0x0000_FF00) >> 8) / 255,
            alpha: Double(value & 0x0000_00FF) / 255
        )
    }

    var hexString: String {
        String(format: "#%02X%02X%02X",
               Int((red * 255).rounded()),
               Int((green * 255).rounded()),
               Int((blue * 255).rounded()))
    }

    /// Perceived luminance (0 dark … 1 light) — used to pick contrasting UI ink.
    var luminance: Double { 0.2126 * red + 0.7152 * green + 0.0722 * blue }

    // MARK: Common colors

    static let white = RGBAColor(red: 1, green: 1, blue: 1)
    static let black = RGBAColor(red: 0, green: 0, blue: 0)
    static let clear = RGBAColor(red: 0, green: 0, blue: 0, alpha: 0)
}
