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
        /// Watches scrolls and clicks while the bubble is up: a scroll moves the badge out from
        /// under a still pointer without any "exited" event, which used to leave it stuck.
        private var monitor: Any?

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
            watchUntilLeft()
        }

        override func mouseExited(with event: NSEvent) {
            dismiss()
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            if newWindow == nil { dismiss() }
        }

        private func dismiss() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            onHover(false)
            InfoTip.shared.hide(owner: self)
        }

        private func watchUntilLeft() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .leftMouseDown, .rightMouseDown]) { [weak self] event in
                if event.type == .scrollWheel {
                    // The content moves after this event is handled; look once it has.
                    DispatchQueue.main.async { self?.dismissIfPointerLeft() }
                } else {
                    self?.dismiss()
                }
                return event
            }
        }

        private func dismissIfPointerLeft() {
            guard let window else { return dismiss() }
            let pointer = convert(window.mouseLocationOutsideOfEventStream, from: nil)
            if !bounds.contains(pointer) { dismiss() }
        }
    }
}
