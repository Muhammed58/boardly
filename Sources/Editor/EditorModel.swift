import SwiftUI

/// Observable editor state for one open project: the live document, current
/// selection/tool, and a snapshot-based undo/redo stack.
///
/// Two mutation paths keep undo sane:
///  • `edit { }` — a discrete change; pushes one undo checkpoint.
///  • `beginInteraction()` / `updateLive { }` / `endInteraction()` — a
///    continuous gesture that collapses to a single checkpoint on release.
@Observable
final class EditorModel {
    var project: Project
    var selectedLayerID: UUID?
    var activeTool: EditorTool = .background
    /// Index of the active page within `project.pages`.
    var pageIndex = 0
    /// When non-nil the canvas is in create mode: the next tap/drag builds this.
    var pending: PendingCreation?
    /// Color applied to newly-created annotations.
    var toolColor: RGBAColor = RGBAColor(hex: "#FF3B30") ?? .black
    /// When true the next canvas tap samples a color instead of selecting.
    var eyedropper = false

    private var undoStack: [EditorCanvas] = []
    private var redoStack: [EditorCanvas] = []
    private var interactionSnapshot: EditorCanvas?
    private let maxUndo = 80

    init(project: Project) {
        var project = project
        if project.pages == nil { project.pages = [project.canvas] }
        self.project = project
        self.selectedLayerID = project.canvas.primaryScreenshot?.id
    }

    // MARK: Pages

    var pageCount: Int { project.pages?.count ?? 1 }

    /// Persist the live canvas back into the pages array. Call before switching
    /// pages, exporting all pages, or saving.
    func commitCurrentPage() {
        if project.pages == nil { project.pages = [project.canvas] }
        if project.pages!.indices.contains(pageIndex) { project.pages![pageIndex] = project.canvas }
    }

    func selectPage(_ index: Int) {
        guard index != pageIndex, let pages = project.pages, pages.indices.contains(index) else { return }
        commitCurrentPage()
        pageIndex = index
        project.canvas = project.pages![index]
        selectedLayerID = project.canvas.primaryScreenshot?.id
        undoStack.removeAll(); redoStack.removeAll()
    }

    func addPage(_ canvas: EditorCanvas) {
        commitCurrentPage()
        project.pages!.append(canvas)
        pageIndex = project.pages!.count - 1
        project.canvas = canvas
        selectedLayerID = canvas.primaryScreenshot?.id
        undoStack.removeAll(); redoStack.removeAll()
        touch()
    }

    func duplicateCurrentPage() { addPage(project.canvas) }

    func deletePage(_ index: Int) {
        guard let pages = project.pages, pages.count > 1, pages.indices.contains(index) else { return }
        project.pages!.remove(at: index)
        pageIndex = min(pageIndex, project.pages!.count - 1)
        project.canvas = project.pages![pageIndex]
        selectedLayerID = project.canvas.primaryScreenshot?.id
        undoStack.removeAll(); redoStack.removeAll()
        touch()
    }

    /// All pages with the live edits reflected (for export).
    func allPagesCommitted() -> [EditorCanvas] {
        commitCurrentPage()
        return project.pages ?? [project.canvas]
    }

    // MARK: Derived

    var canvas: EditorCanvas { project.canvas }
    var selectedLayer: Layer? { selectedLayerID.flatMap { project.canvas[$0] } }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    // MARK: Discrete edits

    func edit(_ mutate: (inout EditorCanvas) -> Void) {
        pushUndo()
        mutate(&project.canvas)
        touch()
    }

    func editSelectedLayer(_ mutate: (inout Layer) -> Void) {
        guard let id = selectedLayerID else { return }
        edit { canvas in
            guard var layer = canvas[id] else { return }
            mutate(&layer)
            canvas[id] = layer
        }
    }

    // MARK: Continuous gestures

    func beginInteraction() { interactionSnapshot = project.canvas }

    func updateLive(_ mutate: (inout EditorCanvas) -> Void) { mutate(&project.canvas) }

    func updateSelectedLayerLive(_ mutate: (inout Layer) -> Void) {
        guard let id = selectedLayerID, var layer = project.canvas[id] else { return }
        mutate(&layer)
        project.canvas[id] = layer
    }

    func endInteraction() {
        if let snap = interactionSnapshot, snap != project.canvas {
            undoStack.append(snap)
            trimUndo()
            redoStack.removeAll()
        }
        interactionSnapshot = nil
        touch()
    }

    // MARK: Layers

    @discardableResult
    func addLayer(_ layer: Layer, select: Bool = true) -> UUID {
        edit { $0.layers.append(layer) }
        if select { selectedLayerID = layer.id; activeTool = tool(for: layer.content) }
        return layer.id
    }

    func deleteSelected() {
        guard let id = selectedLayerID else { return }
        edit { $0.layers.removeAll { $0.id == id } }
        selectedLayerID = nil
    }

    func deleteLayer(_ id: UUID) {
        edit { $0.layers.removeAll { $0.id == id } }
        if selectedLayerID == id { selectedLayerID = nil }
    }

    func duplicateSelected() {
        guard let layer = selectedLayer else { return }
        var copy = layer
        copy.id = UUID()
        copy.transform.center = CGPoint(x: min(layer.transform.center.x + 0.04, 0.96),
                                        y: min(layer.transform.center.y + 0.04, 0.96))
        addLayer(copy)
    }

    /// Move the selected layer up/down the z-order (+1 = toward front).
    func reorderSelected(_ delta: Int) {
        guard let id = selectedLayerID, let i = project.canvas.index(of: id) else { return }
        let j = max(0, min(project.canvas.layers.count - 1, i + delta))
        guard i != j else { return }
        edit { canvas in
            let layer = canvas.layers.remove(at: i)
            canvas.layers.insert(layer, at: j)
        }
    }

    func setBackground(_ style: BackgroundStyle) {
        edit { $0.background = style }
    }

    func setAspect(_ aspect: CanvasAspect) {
        edit { $0.aspect = aspect }
    }

    // MARK: Undo / redo

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(project.canvas)
        project.canvas = previous
        clampSelection()
        touch()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(project.canvas)
        project.canvas = next
        clampSelection()
        touch()
    }

    // MARK: Helpers

    private func pushUndo() {
        undoStack.append(project.canvas)
        trimUndo()
        redoStack.removeAll()
    }

    private func trimUndo() {
        if undoStack.count > maxUndo { undoStack.removeFirst(undoStack.count - maxUndo) }
    }

    private func touch() { project.modifiedAt = Date() }

    private func clampSelection() {
        if let id = selectedLayerID, project.canvas[id] == nil { selectedLayerID = nil }
    }

    private func tool(for content: LayerContent) -> EditorTool {
        switch content {
        case .screenshot: return .frame
        case .text: return .text
        case .annotation: return .annotate
        case .redaction: return .redact
        case .spotlight: return .spotlight
        case .sticker: return .sticker
        case .magnifier: return .annotate
        }
    }
}
