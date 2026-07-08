import SwiftUI

/// Interactive freeform crop over the screenshot. Reports a normalized crop rect.
struct CropSheet: View {
    let image: UIImage
    let onApply: (CGRect) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var crop = CGRect(x: 0.06, y: 0.06, width: 0.88, height: 0.88)

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let area = CGRect(origin: .zero, size: geo.size).insetBy(dx: 20, dy: 20)
                let img = area.fitting(aspect: image.size.aspect)
                let c = screenRect(in: img)
                ZStack {
                    Image(uiImage: image).resizable().frame(width: img.width, height: img.height).position(x: img.midX, y: img.midY)
                    dimOutside(crop: c, canvas: geo.size)
                    Rectangle().strokeBorder(.white, lineWidth: 2)
                        .frame(width: c.width, height: c.height).position(x: c.midX, y: c.midY)
                        .allowsHitTesting(false)
                    thirds(c)
                    ForEach(Corner.allCases, id: \.self) { corner in
                        handle.position(cornerPoint(corner, in: c)).gesture(drag(corner, img: img))
                    }
                    Color.clear.frame(width: c.width, height: c.height).contentShape(Rectangle())
                        .position(x: c.midX, y: c.midY).gesture(moveDrag(img: img))
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Crop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() }.foregroundStyle(.white) }
                ToolbarItem(placement: .topBarTrailing) { Button("Apply") { onApply(crop); dismiss() }.fontWeight(.semibold).foregroundStyle(.white) }
            }
            .toolbarBackground(.black, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    private enum Corner: CaseIterable { case tl, tr, br, bl }

    private var handle: some View {
        Circle().fill(.white).frame(width: 22, height: 22).shadow(radius: 2).contentShape(Circle().inset(by: -10))
    }

    private func screenRect(in img: CGRect) -> CGRect {
        CGRect(x: img.minX + crop.minX * img.width, y: img.minY + crop.minY * img.height,
               width: crop.width * img.width, height: crop.height * img.height)
    }

    private func cornerPoint(_ c: Corner, in r: CGRect) -> CGPoint {
        switch c {
        case .tl: return CGPoint(x: r.minX, y: r.minY); case .tr: return CGPoint(x: r.maxX, y: r.minY)
        case .br: return CGPoint(x: r.maxX, y: r.maxY); case .bl: return CGPoint(x: r.minX, y: r.maxY)
        }
    }

    private func drag(_ corner: Corner, img: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0).onChanged { v in
            let nx = min(max((v.location.x - img.minX) / img.width, 0), 1)
            let ny = min(max((v.location.y - img.minY) / img.height, 0), 1)
            var x0 = crop.minX, y0 = crop.minY, x1 = crop.maxX, y1 = crop.maxY
            switch corner {
            case .tl: x0 = min(nx, x1 - 0.08); y0 = min(ny, y1 - 0.08)
            case .tr: x1 = max(nx, x0 + 0.08); y0 = min(ny, y1 - 0.08)
            case .br: x1 = max(nx, x0 + 0.08); y1 = max(ny, y0 + 0.08)
            case .bl: x0 = min(nx, x1 - 0.08); y1 = max(ny, y0 + 0.08)
            }
            crop = CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
        }
    }

    private func moveDrag(img: CGRect) -> some Gesture {
        DragGesture().onChanged { v in
            let dx = v.translation.width / img.width, dy = v.translation.height / img.height
            let nx = min(max(crop.minX + dx, 0), 1 - crop.width)
            let ny = min(max(crop.minY + dy, 0), 1 - crop.height)
            crop = CGRect(x: nx, y: ny, width: crop.width, height: crop.height)
        }
    }

    private func dimOutside(crop c: CGRect, canvas: CGSize) -> some View {
        Path { p in
            p.addRect(CGRect(origin: .zero, size: canvas))
            p.addRect(c)
        }
        .fill(.black.opacity(0.55), style: FillStyle(eoFill: true))
        .allowsHitTesting(false)
    }

    private func thirds(_ r: CGRect) -> some View {
        Path { p in
            for i in 1...2 {
                let x = r.minX + r.width * CGFloat(i) / 3
                p.move(to: CGPoint(x: x, y: r.minY)); p.addLine(to: CGPoint(x: x, y: r.maxY))
                let y = r.minY + r.height * CGFloat(i) / 3
                p.move(to: CGPoint(x: r.minX, y: y)); p.addLine(to: CGPoint(x: r.maxX, y: y))
            }
        }
        .stroke(.white.opacity(0.35), lineWidth: 0.5)
        .allowsHitTesting(false)
    }
}
