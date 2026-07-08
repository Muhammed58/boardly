import Foundation

/// Hand-off channel between the Share Extension and the app, via the shared
/// App Group container. The extension writes an incoming screenshot here; the
/// app picks it up the next time it becomes active. Foundation-only so it can
/// compile into both targets.
enum SharedInbox {
    static let appGroup = "group.com.muhammedchan.boardly"

    private static var inboxURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("inbox.png")
    }

    static func write(_ data: Data) -> Bool {
        guard let url = inboxURL else { return false }
        do { try data.write(to: url, options: .atomic); return true } catch { return false }
    }

    static var hasPending: Bool {
        guard let url = inboxURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Read and remove the pending image data, if any.
    static func take() -> Data? {
        guard let url = inboxURL, let data = try? Data(contentsOf: url) else { return nil }
        try? FileManager.default.removeItem(at: url)
        return data
    }
}
