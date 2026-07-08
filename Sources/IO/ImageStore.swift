import UIKit

/// On-disk store for imported bitmaps (screenshots, background images,
/// image stickers). Layers reference images by an opaque id string so the
/// `Project` JSON stays small and portable. An in-memory cache keeps the
/// renderer fast during live editing.
final class ImageStore {
    static let shared = ImageStore()

    private let directory: URL
    private let cache = NSCache<NSString, UIImage>()

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("BoardlyImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func url(for id: String) -> URL {
        directory.appendingPathComponent(id).appendingPathExtension("png")
    }

    /// Persist an image and return its new id.
    @discardableResult
    func save(_ image: UIImage, id: String = UUID().uuidString) -> String {
        cache.setObject(image, forKey: id as NSString)
        if let data = image.pngData() {
            try? data.write(to: url(for: id), options: .atomic)
        }
        return id
    }

    /// Load an image by id (memory cache → disk).
    func image(for id: String) -> UIImage? {
        if let cached = cache.object(forKey: id as NSString) { return cached }
        guard let image = UIImage(contentsOfFile: url(for: id).path) else { return nil }
        cache.setObject(image, forKey: id as NSString)
        return image
    }

    func exists(_ id: String) -> Bool {
        cache.object(forKey: id as NSString) != nil || FileManager.default.fileExists(atPath: url(for: id).path)
    }

    func delete(_ id: String) {
        cache.removeObject(forKey: id as NSString)
        try? FileManager.default.removeItem(at: url(for: id))
    }
}
