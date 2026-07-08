import SwiftUI

/// A user-saved look.
struct SavedStyle: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var look: CanvasLook
}

/// Persisted personal library: saved style presets + a brand kit (colors +
/// logo). Stored as a single JSON document in Application Support.
@Observable
final class LibraryStore {
    private(set) var savedStyles: [SavedStyle] = []
    private(set) var brandColors: [RGBAColor] = []
    private(set) var brandLogoID: String?

    private let url: URL
    private let maxStyles = 40

    private struct Data: Codable {
        var savedStyles: [SavedStyle]
        var brandColors: [RGBAColor]
        var brandLogoID: String?
    }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        url = base.appendingPathComponent("Library.json")
        load()
    }

    var hasBrand: Bool { !brandColors.isEmpty }

    func saveStyle(_ look: CanvasLook, name: String) {
        savedStyles.insert(SavedStyle(name: name, look: look), at: 0)
        if savedStyles.count > maxStyles { savedStyles.removeLast(savedStyles.count - maxStyles) }
        persist()
    }

    func deleteStyle(_ id: UUID) {
        savedStyles.removeAll { $0.id == id }
        persist()
    }

    func setBrand(colors: [RGBAColor], logoID: String?) {
        brandColors = colors
        if let logoID { brandLogoID = logoID }
        persist()
    }

    func clearBrand() { brandColors = []; brandLogoID = nil; persist() }

    // MARK: Persistence

    private func load() {
        guard let raw = try? Foundation.Data(contentsOf: url),
              let data = try? JSONDecoder().decode(Data.self, from: raw) else { return }
        savedStyles = data.savedStyles
        brandColors = data.brandColors
        brandLogoID = data.brandLogoID
    }

    private func persist() {
        let data = Data(savedStyles: savedStyles, brandColors: brandColors, brandLogoID: brandLogoID)
        if let raw = try? JSONEncoder().encode(data) { try? raw.write(to: url, options: .atomic) }
    }
}
