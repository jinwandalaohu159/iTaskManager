import SwiftUI

/// A large live figure whose changed characters roll in with a blur-to-sharp settle.
///
/// SwiftUI's `.numericText()` rasterises every frame on the CPU. Here every glyph is
/// pre-rendered once (sharp and blurred) and the motion — slide, fade, spring, and a
/// cross-fade from the blurred to the sharp image — is handed to Core Animation, so it
/// runs in the render server and the app does no per-frame work.
struct LiveNumber: View {
    let text: String
    let value: Double
    var size: CGFloat = 28
    /// When set, the number keeps this string's width (e.g. "00.0 GB") so whatever follows
    /// it doesn't move as digits come and go.
    var template: String? = nil

    @Environment(\.smoothMotion) private var smooth

    var body: some View {
        let font = GlyphCache.font(size: size)
        // An invisible Text with the same font provides layout and baseline alignment.
        Text(template ?? text)
            .font(Font(font as CTFont))
            .opacity(0)
            .overlay(alignment: .leading) {
                RollingText(text: text, value: value, size: size, animated: smooth)
                    .accessibilityHidden(true)
            }
            .accessibilityElement()
            .accessibilityLabel(text)
    }
}

private struct RollingText: NSViewRepresentable {
    let text: String
    let value: Double
    let size: CGFloat
    let animated: Bool

    func makeNSView(context: Context) -> RollingTextView {
        let view = RollingTextView()
        view.size = size
        view.set(text: text, value: value, animated: false)
        return view
    }

    func updateNSView(_ view: RollingTextView, context: Context) {
        view.size = size
        view.set(text: text, value: value, animated: animated && view.window != nil)
    }
}
