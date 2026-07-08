import SwiftUI

/// Emoji stickers — tap to drop one on the canvas.
struct StickerPanel: View {
    let model: EditorModel

    private let emojis = ["😀","😂","😍","🤔","👍","🔥","🎉","✨","💜","⭐️","❤️","✅","❌","⚠️","👀","💡",
                          "🚀","📌","👆","👉","💯","🙌","🥳","😎","🤯","🙏","📈","🏆","🎯","💥","➡️","⬇️"]
    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 8)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(emojis, id: \.self) { emoji in
                    Button { place(emoji) } label: {
                        Text(emoji).font(.system(size: 30))
                            .frame(width: 44, height: 44)
                            .background(Theme.surfaceSunk, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.vertical, 10)
        }
    }

    private func place(_ emoji: String) {
        model.addLayer(LayerFactory.sticker(.emoji(emoji), at: CGPoint(x: 0.5, y: 0.45)))
    }
}
