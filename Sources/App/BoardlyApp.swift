import SwiftUI

@main
struct BoardlyApp: App {
    @State private var store = ProjectStore()
    @State private var library = LibraryStore()
    @AppStorage("appTheme") private var appThemeRaw = AppTheme.system.rawValue

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
                .environment(library)
                .tint(Theme.accent)
                .preferredColorScheme((AppTheme(rawValue: appThemeRaw) ?? .system).colorScheme)
        }
    }
}
