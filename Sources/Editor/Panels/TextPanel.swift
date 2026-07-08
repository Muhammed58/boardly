import SwiftUI

/// Add and style text layers: content, font family/weight, size, color,
/// alignment, stroke, and a pill background.
struct TextPanel: View {
    let model: EditorModel
    @FocusState private var editing: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let text = model.selectedText {
                    editor(text)
                } else {
                    Button { addText() } label: {
                        Label("Add Text", systemImage: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Theme.accentSoft, in: Capsule())
                            .foregroundStyle(Theme.accent)
                    }
                    .padding(.horizontal, Theme.Space.md)

                    Text("HEADLINE STYLES").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.inkTertiary)
                        .padding(.horizontal, Theme.Space.md).padding(.top, 2)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(headlineTemplates) { template in
                                Button { addTemplate(template.content) } label: {
                                    Text(template.name)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Theme.ink)
                                        .padding(.horizontal, 14).padding(.vertical, 12)
                                        .background(Theme.surfaceSunk, in: RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Theme.Space.md)
                    }
                }
            }
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder private func editor(_ text: TextContent) -> some View {
        TextField("Type…", text: Binding(
            get: { text.string },
            set: { v in model.updateSelectedText(live: true) { $0.string = v } }), axis: .vertical)
            .font(.system(size: 15))
            .focused($editing)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Theme.surfaceSunk, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, Theme.Space.md)
            .onChange(of: editing) { _, focused in focused ? model.beginInteraction() : model.endInteraction() }

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FontFamily.allCases) { family in
                    PanelChip(title: family.displayName, selected: text.family == family) {
                        model.updateSelectedText { $0.family = family }
                    }
                }
                Divider().frame(height: 20)
                ForEach(FontWeight.allCases, id: \.self) { weight in
                    PanelChip(title: weight.rawValue.capitalized, selected: text.weight == weight) {
                        model.updateSelectedText { $0.weight = weight }
                    }
                }
            }
            .padding(.horizontal, Theme.Space.md)
        }

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button { model.eyedropper = true } label: {
                    Image(systemName: "eyedropper.halffull")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(model.eyedropper ? .white : Theme.accent)
                        .frame(width: 28, height: 28)
                        .background(model.eyedropper ? Theme.accent : Theme.accentSoft, in: Circle())
                }
                .buttonStyle(.plain)
                ForEach(ToolPalette.colors, id: \.self) { color in
                    ColorDot(color: color, selected: text.color == color) {
                        model.updateSelectedText { $0.color = color; $0.gradient = nil }
                    }
                }
            }
            .padding(.horizontal, Theme.Space.md)
        }

        effectsRow(text)

        HStack(spacing: 8) {
            ForEach(TextAlign.allCases, id: \.self) { align in
                PanelChip(title: "", systemImage: symbol(align), selected: text.align == align) {
                    model.updateSelectedText { $0.align = align }
                }
            }
            Spacer()
            PanelChip(title: "Stroke", selected: text.hasStroke) {
                model.updateSelectedText { $0.hasStroke.toggle() }
            }
            PanelChip(title: "Label", selected: text.background != nil) {
                model.updateSelectedText { $0.background = $0.background == nil ? .black : nil }
            }
        }
        .padding(.horizontal, Theme.Space.md)

        EditSlider(title: "Size", value: Binding(
            get: { text.fontSize }, set: { v in model.updateSelectedText(live: true) { $0.fontSize = v } }),
            range: 0.02...0.16, onEditing: { model.slider(begin: $0) })
            .padding(.horizontal, Theme.Space.md)
    }

    @ViewBuilder private func effectsRow(_ text: TextContent) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                PanelChip(title: "Gradient", selected: text.gradient != nil) {
                    model.updateSelectedText {
                        $0.gradient = $0.gradient == nil ? [RGBAColor(hex: "#FF8A00")!, RGBAColor(hex: "#FF3D77")!] : nil
                    }
                }
                Divider().frame(height: 20)
                Text("Mark").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.inkSecondary)
                PanelChip(title: "Off", selected: text.highlight == nil) { model.updateSelectedText { $0.highlight = nil } }
                ForEach(TextHighlight.allCases) { hl in
                    PanelChip(title: hl.displayName, selected: text.highlight == hl) {
                        model.updateSelectedText { $0.highlight = hl }
                    }
                }
            }
            .padding(.horizontal, Theme.Space.md)
        }
        EditSlider(title: "Curve", value: Binding(
            get: { text.curve ?? 0 },
            set: { v in model.updateSelectedText(live: true) { $0.curve = abs(v) < 0.02 ? nil : v } }),
            range: -1...1, onEditing: { model.slider(begin: $0) })
            .padding(.horizontal, Theme.Space.md)
    }

    private func symbol(_ a: TextAlign) -> String {
        switch a { case .leading: return "text.alignleft"; case .center: return "text.aligncenter"; case .trailing: return "text.alignright" }
    }

    private func addText() {
        model.addLayer(LayerFactory.text(at: CGPoint(x: 0.5, y: 0.35)))
    }

    private func addTemplate(_ content: TextContent) {
        model.addLayer(Layer(
            name: "Text",
            transform: LayerTransform(center: CGPoint(x: 0.5, y: 0.28), size: CGSize(width: 0.84, height: 0.2)),
            content: .text(content)))
    }

    private struct HeadlineTemplate: Identifiable { let id = UUID(); let name: String; let content: TextContent }

    private var headlineTemplates: [HeadlineTemplate] {
        var bold = TextContent(); bold.string = "Bold headline"; bold.weight = .heavy; bold.fontSize = 0.062; bold.color = .white
        var grad = TextContent(); grad.string = "Gradient"; grad.weight = .heavy; grad.fontSize = 0.062; grad.gradient = [RGBAColor(hex: "#FF8A00")!, RGBAColor(hex: "#FF3D77")!]; grad.hasShadow = false
        var outline = TextContent(); outline.string = "Outline"; outline.weight = .heavy; outline.fontSize = 0.062; outline.color = .white; outline.hasStroke = true; outline.strokeColor = .black; outline.hasShadow = false
        var marker = TextContent(); marker.string = "Marker"; marker.weight = .bold; marker.fontSize = 0.05; marker.color = .black; marker.highlight = .marker; marker.highlightColor = RGBAColor(hex: "#FFE24D"); marker.hasShadow = false
        var label = TextContent(); label.string = "Label"; label.weight = .bold; label.fontSize = 0.045; label.color = .white; label.background = RGBAColor(hex: "#111111"); label.hasShadow = false
        var rounded = TextContent(); rounded.string = "Rounded"; rounded.family = .rounded; rounded.weight = .heavy; rounded.fontSize = 0.06; rounded.color = .white
        return [
            .init(name: "Bold", content: bold),
            .init(name: "Gradient", content: grad),
            .init(name: "Outline", content: outline),
            .init(name: "Marker", content: marker),
            .init(name: "Label", content: label),
            .init(name: "Rounded", content: rounded),
        ]
    }
}
