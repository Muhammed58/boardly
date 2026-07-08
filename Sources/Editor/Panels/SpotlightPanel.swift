import SwiftUI

/// Focus attention: dim everything except a highlighted region.
struct SpotlightPanel: View {
    let model: EditorModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    AddToolButton(title: "Spotlight", systemImage: "flashlight.on.fill",
                                  active: model.pending == .spotlight) {
                        model.pending = .spotlight
                    }
                    Text("Drag on the canvas to spotlight an area.")
                        .font(.system(size: 12)).foregroundStyle(Theme.inkTertiary)
                    Spacer()
                }
                .padding(.horizontal, Theme.Space.md)

                if let s = model.selectedSpotlight {
                    HStack(spacing: 8) {
                        ForEach(SpotlightShape.allCases, id: \.self) { shape in
                            PanelChip(title: shape == .ellipse ? "Oval" : "Rect", selected: s.shape == shape) {
                                model.updateSelectedSpotlight { $0.shape = shape }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Space.md)

                    EditSlider(title: "Dim", value: Binding(
                        get: { s.dimOpacity }, set: { v in model.updateSelectedSpotlight(live: true) { $0.dimOpacity = v } }),
                        range: 0.1...0.9, onEditing: { model.slider(begin: $0) })
                        .padding(.horizontal, Theme.Space.md)
                    if s.shape == .rectangle {
                        EditSlider(title: "Corners", value: Binding(
                            get: { s.cornerRadius }, set: { v in model.updateSelectedSpotlight(live: true) { $0.cornerRadius = v } }),
                            range: 0...0.1, onEditing: { model.slider(begin: $0) })
                            .padding(.horizontal, Theme.Space.md)
                    }
                }
            }
            .padding(.vertical, 10)
        }
    }
}
