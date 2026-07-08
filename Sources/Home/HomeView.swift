import SwiftUI
import PhotosUI

/// Landing screen: import a screenshot or reopen a saved project.
struct HomeView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var photoItem: PhotosPickerItem?
    @State private var openProject: Project?
    @State private var isImporting = false
    @State private var importError: String?
    @State private var latestShot: UIImage?
    @State private var showBatch = false
    @State private var showAppStore = false
    @State private var showSettings = false
    @AppStorage("appTheme") private var appThemeRaw = AppTheme.system.rawValue

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {
                    header
                    if let latestShot { latestBanner(latestShot) }
                    importCard
                    if !store.projects.isEmpty { recentSection }
                    else { emptyState }
                }
                .padding(Theme.Space.md)
                .padding(.bottom, 40)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(item: $openProject) { project in
            EditorView(project: project) { updated, thumb in
                store.save(updated, thumbnail: thumb)
            }
        }
        .onChange(of: photoItem) { _, item in importPhoto(item) }
        .fullScreenCover(isPresented: $showBatch) { BatchView() }
        .sheet(isPresented: $showAppStore) {
            AppStoreSetupView { project in
                showAppStore = false
                openProject = project
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .task {
            checkSharedInbox()
            if latestShot == nil, PhotoLibrary.isReadable {
                latestShot = await PhotoLibrary.latestScreenshot(promptIfNeeded: false)
            }
            #if DEBUG
            // Headless verification hook (debug builds only).
            let demo = ProcessInfo.processInfo.environment["BOARDLY_DEMO"]
            if openProject == nil, let demo {
                let image = SampleScreenshot.make().normalizedUp()
                let id = ImageStore.shared.save(image)
                if demo == "appstore" {
                    let ids = [id, ImageStore.shared.save(SampleScreenshot.make()), ImageStore.shared.save(SampleScreenshot.make())]
                    openProject = AppStoreTemplates.generateSet(name: "App Store", template: AppStoreTemplates.template("bold"), imageIDs: ids, now: Date())
                } else {
                    openProject = DemoShowcase.project(imageID: id, imageSize: image.size)
                }
            }
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { checkSharedInbox() }
        }
        .alert("Couldn't import image", isPresented: .constant(importError != nil)) {
            Button("OK") { importError = nil }
        } message: { Text(importError ?? "") }
    }

    // MARK: Sections

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Boardly")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("Beautiful screenshots, ready to post.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.inkSecondary)
                    .padding(6)
                    .contentShape(Rectangle())
            }
        }
        .padding(.top, Theme.Space.md)
    }

    private var importCard: some View {
        VStack(spacing: Theme.Space.sm) {
            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                Label("New Screenshot", systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle())

            HStack(spacing: Theme.Space.sm) {
                secondaryButton("Paste", systemImage: "doc.on.clipboard") { pasteFromClipboard() }
                secondaryButton("Latest", systemImage: "clock.arrow.circlepath") { importLatest() }
            }
            HStack(spacing: Theme.Space.sm) {
                secondaryButton("Batch", systemImage: "square.stack.3d.up") { showBatch = true }
                secondaryButton("Try a sample", systemImage: "wand.and.stars") { present(SampleScreenshot.make()) }
            }
            Button { showAppStore = true } label: {
                Label("App Store Studio", systemImage: "app.badge.checkmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(
                        LinearGradient(colors: [Theme.accentDeep, Theme.accent], startPoint: .leading, endPoint: .trailing),
                        in: Capsule()
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Space.md)
        .cardSurface(radius: Theme.Radius.lg)
        .contentShape(Rectangle())
        .zIndex(1)
        .overlay {
            if isImporting { ProgressView().tint(Theme.accent) }
        }
    }

    private func secondaryButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.surfaceSunk, in: Capsule())
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("Recent")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.ink)
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(store.projects) { project in
                    ProjectTile(project: project,
                                thumbnail: store.thumbnail(for: project.id),
                                onOpen: { openProject = project },
                                onDelete: { store.delete(project) })
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(Theme.inkTertiary)
            Text("No screenshots yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.inkSecondary)
            Text("Import one to start editing.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    // MARK: Import

    private func importPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        isImporting = true
        Task {
            defer { isImporting = false; photoItem = nil }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                importError = "That image could not be read."
                return
            }
            present(image)
        }
    }

    private func pasteFromClipboard() {
        guard let image = UIPasteboard.general.image else {
            importError = "No image on the clipboard."
            return
        }
        present(image)
    }

    private func present(_ image: UIImage) {
        let normalized = image.normalizedUp()
        let id = ImageStore.shared.save(normalized)
        openProject = Project.new(imageID: id, imageSize: normalized.size, now: Date())
    }

    private func importLatest() {
        Task {
            if let image = await PhotoLibrary.latestScreenshot(promptIfNeeded: true) { present(image) }
            else { importError = "No screenshot found in your library." }
        }
    }

    private func latestBanner(_ image: UIImage) -> some View {
        Button { present(image); latestShot = nil } label: {
            HStack(spacing: 12) {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: 44, height: 60).clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Beautify your latest screenshot").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text("Tap to open it in the editor").font(.system(size: 12)).foregroundStyle(Theme.inkSecondary)
                }
                Spacer()
                Image(systemName: "arrow.forward.circle.fill").font(.system(size: 22)).foregroundStyle(Theme.accent)
                Button { latestShot = nil } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.inkTertiary) }
            }
            .padding(12)
            .cardSurface(radius: Theme.Radius.md)
        }
        .buttonStyle(.plain)
    }

    /// Pick up a screenshot handed off by the Share Extension.
    private func checkSharedInbox() {
        guard openProject == nil, let data = SharedInbox.take(), let image = UIImage(data: data) else { return }
        present(image)
    }
}

/// A single gallery tile.
private struct ProjectTile: View {
    let project: Project
    let thumbnail: UIImage?
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .fill(Theme.surfaceSunk)
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .strokeBorder(Theme.separator, lineWidth: 1)
                )

                Text(project.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(project.modifiedAt.formatted(.relative(presentation: .named)))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
        }
    }
}
