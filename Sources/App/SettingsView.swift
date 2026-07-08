import SwiftUI

/// App settings: appearance, support, and legal. Not required by Apple for a
/// free app, but it's good practice and gives reviewers the Privacy/Support links.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage("appTheme") private var appThemeRaw = AppTheme.system.rawValue

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Picker("Theme", selection: Binding(
                        get: { AppTheme(rawValue: appThemeRaw) ?? .system },
                        set: { appThemeRaw = $0.rawValue })) {
                        ForEach(AppTheme.allCases) { theme in
                            Label(theme.label, systemImage: theme.symbol).tag(theme)
                        }
                    }
                }

                Section("Support") {
                    externalLink("Contact & Support", "envelope", LegalText.supportURL)
                    Button { rate() } label: {
                        Label("Rate Boardly", systemImage: "star").foregroundStyle(Theme.ink)
                    }
                }

                Section("Legal") {
                    externalLink("Privacy Policy", "hand.raised", LegalText.privacyPolicyURL)
                    externalLink("Terms of Use", "doc.text", LegalText.termsURL)
                }

                Section {
                    HStack {
                        Text("Version"); Spacer()
                        Text(version).foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Boardly runs 100% on your device. No account, no cloud, no tracking.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
        }
        .tint(Theme.accent)
    }

    private func externalLink(_ title: String, _ symbol: String, _ urlString: String) -> some View {
        Link(destination: URL(string: urlString) ?? URL(string: "https://www.indiesoftwaredev.com")!) {
            HStack {
                Label(title, systemImage: symbol).foregroundStyle(Theme.ink)
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            }
        }
    }

    private func rate() {
        if let url = URL(string: "https://apps.apple.com/app/id6749162571?action=write-review") { openURL(url) }
    }
}
