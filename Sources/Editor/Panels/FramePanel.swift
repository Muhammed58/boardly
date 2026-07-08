import SwiftUI

/// Screenshot styling: device/browser/window frame, corner radius, shadow,
/// padding, and 3-D tilt. Operates on the selected screenshot (or the primary).
struct FramePanel: View {
    let model: EditorModel
    @State private var isLifting = false

    var body: some View {
        if let content = model.screenshotContent {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    frameChips(content)
                    if content.frame.isBrowser { urlField(content) }
                    removeBackgroundButton
                    extrasRow(content)
                    shadowChips(content)
                    slidersRow(content)
                }
                .padding(.horizontal, Theme.Space.md)
                .padding(.vertical, 10)
            }
        } else {
            ComingSoonPanel(tool: .frame)
        }
    }

    private var removeBackgroundButton: some View {
        Button { removeBackground() } label: {
            HStack(spacing: 7) {
                if isLifting { ProgressView().controlSize(.small) }
                else { Image(systemName: "person.and.background.dotted") }
                Text(isLifting ? "Removing…" : "Remove Background").font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(Theme.accentSoft, in: Capsule())
        }
        .disabled(isLifting)
    }

    private func removeBackground() {
        guard !isLifting, let id = model.screenshotID,
              case .screenshot(let s)? = model.project.canvas[id]?.content,
              let image = ImageStore.shared.image(for: s.imageID) else { return }
        isLifting = true
        Task {
            defer { isLifting = false }
            guard let cutout = await SubjectLifter.lift(image) else { return }
            let newID = ImageStore.shared.save(cutout)
            model.setScreenshot { $0.imageID = newID; $0.frame = .none; $0.shadow = .medium }
        }
    }

    private func frameChips(_ content: ScreenshotContent) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DeviceFrameKind.allCases) { kind in
                    PanelChip(title: kind.displayName, systemImage: kind.symbol, selected: content.frame == kind) {
                        model.setScreenshot { $0.frame = kind }
                    }
                }
            }
        }
    }

    private func urlField(_ content: ScreenshotContent) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "link").font(.system(size: 12)).foregroundStyle(Theme.inkTertiary)
            TextField("URL", text: Binding(
                get: { content.browserURL },
                set: { v in model.setScreenshot { $0.browserURL = v } }
            ))
            .font(.system(size: 13))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Theme.surfaceSunk, in: Capsule())
    }

    private func shadowChips(_ content: ScreenshotContent) -> some View {
        HStack(spacing: 8) {
            Text("Shadow").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.inkSecondary)
            ForEach(shadowOptions, id: \.0) { name, style in
                PanelChip(title: name, selected: content.shadow == style) {
                    model.setScreenshot { $0.shadow = style }
                }
            }
        }
    }

    private var shadowOptions: [(String, ShadowStyle)] {
        [("None", .none), ("Soft", .soft), ("Medium", .medium), ("Strong", .strong)]
    }

    @ViewBuilder private func extrasRow(_ content: ScreenshotContent) -> some View {
        if content.frame == .none {
            HStack(spacing: 8) {
                Text("Shape").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.inkSecondary)
                ForEach(ScreenshotClip.allCases) { shape in
                    PanelChip(title: shape.displayName, selected: (content.clipShape ?? .roundedRect) == shape) {
                        model.setScreenshot { $0.clipShape = shape }
                    }
                }
            }
        }
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                PanelChip(title: "Clean bar", systemImage: "iphone.gen3", selected: content.cleanStatusBar != nil) {
                    model.setScreenshot { $0.cleanStatusBar = $0.cleanStatusBar == nil ? .dark : nil }
                }
                if content.cleanStatusBar != nil {
                    ForEach(StatusBarStyle.allCases) { st in
                        PanelChip(title: st.displayName, selected: content.cleanStatusBar == st) {
                            model.setScreenshot { $0.cleanStatusBar = st }
                        }
                    }
                }
                PanelChip(title: "Glass", selected: content.glass == true) {
                    model.setScreenshot { $0.glass = !($0.glass ?? false) }
                }
                PanelChip(title: "Reflection", selected: content.reflection == true) {
                    model.setScreenshot { $0.reflection = !($0.reflection ?? false) }
                }
            }
        }
    }

    private func slidersRow(_ content: ScreenshotContent) -> some View {
        VStack(spacing: 8) {
            EditSlider(title: "Corners", value: Binding(
                get: { content.cornerRadius }, set: { v in model.updateScreenshotLive { $0.cornerRadius = v } }),
                range: 0...0.25, onEditing: { model.slider(begin: $0) })
            EditSlider(title: "Padding", value: paddingBinding, range: 0...0.42,
                       onEditing: { model.slider(begin: $0) })
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text("Tilt").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.inkSecondary)
                    PanelChip(title: "Flat", selected: false) { setTilt(0, 0) }
                    PanelChip(title: "3D L", selected: false) { setTilt(0.12, 0.18) }
                    PanelChip(title: "3D R", selected: false) { setTilt(0.12, -0.18) }
                    PanelChip(title: "Up", selected: false) { setTilt(-0.16, 0) }
                }
            }
            HStack(spacing: 16) {
                EditSlider(title: "Tilt ↕", value: tiltBinding(\.rotationX), range: -0.6...0.6,
                           onEditing: { model.slider(begin: $0) })
                EditSlider(title: "Tilt ↔", value: tiltBinding(\.rotationY), range: -0.6...0.6,
                           onEditing: { model.slider(begin: $0) })
            }
        }
    }

    private var paddingBinding: Binding<Double> {
        Binding(
            get: { Double(1 - (model.screenshotTransform?.size.width ?? 0.72)) / 2 },
            set: { p in
                let s = CGFloat(1 - 2 * p)
                model.updateScreenshotTransformLive { $0.size = CGSize(width: s, height: s) }
            }
        )
    }

    private func setTilt(_ x: Double, _ y: Double) {
        model.beginInteraction()
        model.updateScreenshotTransformLive { $0.rotationX = x; $0.rotationY = y }
        model.endInteraction()
    }

    private func tiltBinding(_ keyPath: WritableKeyPath<LayerTransform, Double>) -> Binding<Double> {
        Binding(
            get: { model.screenshotTransform?[keyPath: keyPath] ?? 0 },
            set: { v in model.updateScreenshotTransformLive { $0[keyPath: keyPath] = v } }
        )
    }
}
