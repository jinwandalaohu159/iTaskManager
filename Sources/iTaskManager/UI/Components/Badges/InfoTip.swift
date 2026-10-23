import AppKit
import SwiftUI

/// One floating bubble shared by every badge. It's a borderless panel that ignores the mouse,
/// so appearing under the pointer can't end the hover that summoned it (an NSPopover there
/// flickers open and shut), and it fades and slides with Core Animation rather than building
/// a popover window each time.
@MainActor
final class InfoTip {
    static let shared = InfoTip()

    private static let maxWidth: CGFloat = 260
    private static let gap: CGFloat = 6

    private let panel: NSPanel
    private let host = NSHostingView(rootView: TipBubble(text: "", width: 0))
    private var owner: ObjectIdentifier?

    private init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = true
        panel.animationBehavior = .none
        panel.collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
        host.wantsLayer = true
        panel.contentView = host
    }

    /// Shows `text` under `anchor` (screen coordinates), or above it near the bottom of the screen.
    func show(_ text: String, below anchor: NSRect, on screen: NSScreen?, owner: AnyObject) {
        self.owner = ObjectIdentifier(owner)
        let font = NSFont.preferredFont(forTextStyle: .callout)
        let natural = ceil((text as NSString).size(withAttributes: [.font: font]).width) + 1
        host.rootView = TipBubble(text: text, width: min(natural, Self.maxWidth))
        let size = host.fittingSize

        var origin = NSPoint(x: anchor.midX - size.width / 2, y: anchor.minY - Self.gap - size.height)
        var rises = true
        if let visible = screen?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
            if origin.y < visible.minY + 8 {
                origin.y = anchor.maxY + Self.gap
                rises = false
            }
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.invalidateShadow()

        let appearing = !panel.isVisible || panel.alphaValue < 1
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFront(nil)
        }
        if appearing, let layer = host.layer {
            // A short slide towards the anchor while it fades in.
            let slide = CABasicAnimation(keyPath: "transform.translation.y")
            slide.fromValue = rises ? -4 : 4
            slide.toValue = 0
            slide.duration = 0.18
            slide.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(slide, forKey: "slide")
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func hide(owner: AnyObject) {
        guard self.owner == ObjectIdentifier(owner) else { return }
        self.owner = nil
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(140))
            // Unless another badge took the bubble over in the meantime.
            guard let self, self.owner == nil else { return }
            self.panel.orderOut(nil)
        }
    }
}

private struct TipBubble: View {
    let text: String
    let width: CGFloat

    var body: some View {
        Text(text)
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: width, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08))
            }
    }
}
