import AppKit
import SwiftUI

/// A small "?" that shows an explanation while the pointer is over it, in place of footnote
/// text under a setting or figure.
struct InfoBadge: View {
    let text: String

    @State private var hovering = false

    var body: some View {
        Image(systemName: "questionmark.circle")
            .font(.callout)
            .foregroundStyle(hovering ? .secondary : .tertiary)
            .overlay { InfoTipAnchor(text: text, hovering: $hovering) }
            .accessibilityLabel(text)
    }
}

extension View {
    /// The view followed by an `InfoBadge`.
    func info(_ text: String) -> some View {
        HStack(spacing: 6) {
            self
            InfoBadge(text: text)
        }
    }
}

// MARK: - Hover tracking

/// Tracks the pointer over the badge with a plain tracking area and drives the shared bubble.
private struct InfoTipAnchor: NSViewRepresentable {
    let text: String
    @Binding var hovering: Bool

    func makeNSView(context: Context) -> AnchorView {
        AnchorView()
    }

    func updateNSView(_ view: AnchorView, context: Context) {
        view.text = text
        view.onHover = { hovering = $0 }
    }

    final class AnchorView: NSView {
        var text = ""
        var onHover: (Bool) -> Void = { _ in }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(
                rect: .zero,
                options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
                owner: self
            ))
        }

        override func mouseEntered(with event: NSEvent) {
            guard let window else { return }
            onHover(true)
            let rect = window.convertToScreen(convert(bounds, to: nil))
            InfoTip.shared.show(text, below: rect, on: window.screen, owner: self)
        }

        override func mouseExited(with event: NSEvent) {
            onHover(false)
            InfoTip.shared.hide(owner: self)
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            if newWindow == nil { InfoTip.shared.hide(owner: self) }
        }
    }
}
