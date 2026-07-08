import SwiftUI

/// Observable list of saved projects, persisted as JSON documents plus JPEG
/// thumbnails under Application Support. Backs the Home gallery.
@Observable
final class ProjectStore {
    private(set) var projects: [Project] = []

    private let projectsDir: URL
    private let thumbsDir: URL
    private let maxProjects = 200

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        projectsDir = base.appendingPathComponent("Projects", isDirectory: true)
        thumbsDir = base.appendingPathComponent("Thumbnails", isDirectory: true)
        for dir in [projectsDir, thumbsDir] {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        loadAll()
    }

    // MARK: Loading

    func loadAll() {
        let decoder = JSONDecoder()
        let urls = (try? FileManager.default.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: nil)) ?? []
        let loaded = urls
            .filter { $0.pathExtension == "json" }
            .compactMap { try? decoder.decode(Project.self, from: Data(contentsOf: $0)) }
        projects = loaded.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    // MARK: Mutations

    func save(_ project: Project, thumbnail: UIImage?) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        if let data = try? encoder.encode(project) {
            try? data.write(to: url(forProject: project.id), options: .atomic)
        }
        if let thumbnail, let data = thumbnail.jpegData(compressionQuality: 0.8) {
            try? data.write(to: url(forThumb: project.id), options: .atomic)
        }
        if let i = projects.firstIndex(where: { $0.id == project.id }) {
            projects[i] = project
        } else {
            projects.append(project)
        }
        projects.sort { $0.modifiedAt > $1.modifiedAt }
        enforceLimit()
    }

    func delete(_ project: Project) {
        try? FileManager.default.removeItem(at: url(forProject: project.id))
        try? FileManager.default.removeItem(at: url(forThumb: project.id))
        // Reclaim referenced images.
        for layer in project.canvas.layers {
            if case .screenshot(let s) = layer.content { ImageStore.shared.delete(s.imageID) }
        }
        projects.removeAll { $0.id == project.id }
    }

    func project(with id: UUID) -> Project? { projects.first { $0.id == id } }

    func thumbnail(for id: UUID) -> UIImage? { UIImage(contentsOfFile: url(forThumb: id).path) }

    // MARK: Files

    private func url(forProject id: UUID) -> URL {
        projectsDir.appendingPathComponent(id.uuidString).appendingPathExtension("json")
    }
    private func url(forThumb id: UUID) -> URL {
        thumbsDir.appendingPathComponent(id.uuidString).appendingPathExtension("jpg")
    }

    private func enforceLimit() {
        guard projects.count > maxProjects else { return }
        for stale in projects.suffix(projects.count - maxProjects) { delete(stale) }
    }
}
