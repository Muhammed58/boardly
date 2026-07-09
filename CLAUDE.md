# Boardly (native)

> **THIS is the real, current Boardly project.**
> Absolute path: `/Users/muhammetarslantas/Desktop/Muhammet/CodingProject/Mobile/BoardlyNative`
> It is a **native SwiftUI** app. Do NOT confuse it with the deprecated Expo/React
> Native project at `/Users/muhammetarslantas/Desktop/Muhammet/CodingProject/DELETE/boardly`
> (that folder is being deleted — never build or edit it).

Native Swift rewrite of the Expo "boardly" app — an on-device **screenshot editor**
for social media. SwiftUI + Core Graphics + Core Image + Vision. iOS 18+, no
third-party dependencies, no backend. Bundle id `com.muhammedchan.boardly`
(reuses the live App Store identifier — this build replaces it).

The folder is `BoardlyNative` (not `Boardly`) to avoid a case-insensitive
filesystem collision with the sibling Expo `boardly` project. The Xcode project,
display name, and bundle id are all "Boardly".

## Build & run

```sh
xcodegen generate            # after adding/removing files
SIM="<simulator-udid>"       # e.g. iPhone 17 Pro Max
xcodebuild -project Boardly.xcodeproj -scheme Boardly -sdk iphonesimulator \
  -destination "id=$SIM" -configuration Debug -derivedDataPath build \
  build CODE_SIGNING_ALLOWED=NO
xcrun simctl install "$SIM" build/Build/Products/Debug-iphonesimulator/Boardly.app
xcrun simctl launch "$SIM" com.muhammedchan.boardly
```

Launch env `BOARDLY_DEMO=1` (via `SIMCTL_CHILD_BOARDLY_DEMO=1`) auto-opens a
composed sample project in the editor — used for headless screenshot verification.

## Architecture invariants (do not violate)

1. **Single render path.** `CanvasRenderer` (Core Graphics / Core Image) renders
   ALL visual content — background, framed screenshot, redaction, spotlight,
   annotations, text, stickers — for BOTH the on-screen preview and the export.
   SwiftUI draws only selection gizmos (`SelectionGizmoView`), never content.
   This is what guarantees WYSIWYG (the pain point of the RN version).
2. **Normalized coordinates.** Every `LayerTransform` (center, size) and all
   annotation points are 0…1 relative to the canvas. The renderer scales to the
   output pixel size; the editor scales to the on-screen `display` rect
   (`CanvasGeometry`). The same values drive preview and export.
3. **Render passes.** Layers draw in z-order into a running accumulator. Only
   blur/pixelate **redaction** needs to read the pixels beneath it, so it flushes
   the accumulator, applies a Core Image effect to the region, and continues.
4. **Undo is snapshot-based.** All model mutation goes through `EditorModel`:
   `edit { }` pushes one checkpoint; `beginInteraction()` / `updateLive { }` /
   `endInteraction()` collapse a continuous gesture (drag, slider) into one.
   Never mutate `project.canvas` outside these.
5. **Images live in `ImageStore`,** referenced by id string, so `Project` JSON
   stays small. Projects persist as JSON + JPEG thumbnails in `ProjectStore`.

## Layout (`Sources/`)

- `App/` — `BoardlyApp` entry.
- `Model/` — `Project`, `EditorCanvas`, `Layer`/`LayerContent`, `LayerTransform`,
  `BackgroundStyle` (+presets), `CanvasAspect`, styles, `RGBAColor`, `ProjectStore`.
- `Canvas/` — `CanvasRenderer`, `FrameRenderer` (vector device/browser/window
  chrome), `TextLayerRenderer`, `AnnotationRenderer`, `PerspectiveWarp` (3-D tilt),
  `MeshBackground`.
- `Editor/` — `EditorView`, `EditorModel` (+ convenience), `EditorCanvasView`
  (render + gesture state machine), `SelectionGizmoView`, `CanvasGeometry`,
  `LayerFactory`, `Panels/` (one panel per tool + `PanelKit`).
- `Home/` — `HomeView` gallery + import.
- `Vision/` — `SubjectLifter` (foreground-instance mask), `SensitiveContentDetector`
  (auto-redact of emails/numbers/tokens/faces).
- `IO/` — `ImageStore`, `Exporter`/`ActivityView`, `SharedInbox`, `SampleScreenshot`.

## Share Extension

`BoardlyShare` (app-extension target) receives an image from the iOS share sheet,
writes it to the App Group container (`group.com.muhammedchan.boardly`), and the
app imports it on next activation (`HomeView.checkSharedInbox`). Both targets carry
the App Group entitlement. Requires a signed build to exercise on device.

## Tools

Bottom bar tools (`EditorTool`): Background · Frame · Text · Draw · Redact ·
Spotlight · Sticker · Crop · Layers. "Frame" also hosts Remove Background
(subject lift); "Crop" hosts aspect presets + the one-tap promo template;
"Layers" hosts collage (add more screenshot layers).
