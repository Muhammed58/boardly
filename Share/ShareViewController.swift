import UIKit
import UniformTypeIdentifiers

/// Receives a shared screenshot, stashes it in the App Group inbox, and shows a
/// brief confirmation. Boardly imports it the next time it becomes active.
final class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        handleShare()
    }

    private func handleShare() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first(where: {
                  $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
              }) else {
            finish(saved: false); return
        }

        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] data, _ in
            let saved = data.map { SharedInbox.write($0) } ?? false
            DispatchQueue.main.async { self?.confirm(saved: saved) }
        }
    }

    private func confirm(saved: Bool) {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 18
        card.layer.cornerCurve = .continuous
        card.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = saved ? "Saved to Boardly\nOpen the app to edit" : "Couldn't import image"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(label)
        view.addSubview(card)
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8),
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -22),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 26),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -26),
        ])

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in self?.finish(saved: saved) }
    }

    private func finish(saved: Bool) {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
