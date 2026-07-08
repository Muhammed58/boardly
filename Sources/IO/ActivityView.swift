import SwiftUI
import UIKit

/// Thin wrapper over `UIActivityViewController` for the system share sheet
/// (includes "Save Image", AirDrop, Messages, etc.).
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Identifiable box so a rendered image can drive `.sheet(item:)`.
struct ShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Identifiable box for an arbitrary set of share items (files, images).
struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}
