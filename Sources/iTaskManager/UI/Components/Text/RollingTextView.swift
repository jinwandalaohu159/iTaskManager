import AppKit
import QuartzCore

/// One layer per character, built from `GlyphCache` images. Changed characters roll out and
/// in (slide, fade, blur-to-sharp) entirely in Core Animation; unchanged ones slide over.
final class RollingTextView: NSView {
    var size: CGFloat = 28 {
        didSet { if size != oldValue { rebuildAll() } }
    }

    private var text = ""
    private var value = 0.0
    /// One layer per character, left to right.
    private var slots: [CALayer] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func set(text newText: String, value newValue: Double, animated: Bool) {
        guard newText != text else { return }
        let oldChars = Array(text)
        let newChars = Array(newText)
        let rising = newValue >= value
        text = newText
        value = newValue

        guard animated, !slots.isEmpty, bounds.height > 0 else {
            rebuildAll()
            return
        }

        let font = GlyphCache.font(size: size)
        let travel = GlyphCache.lineHeight(font) * 0.36
        let xs = offsets(for: newChars)
        var newSlots = [CALayer?](repeating: nil, count: newChars.count)
        var outgoing: [CALayer] = []
        var stagger = 0.0
        let now = CACurrentMediaTime()

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // Match characters from the right so units and decimals stay anchored.
        for k in 0..<max(oldChars.count, newChars.count) {
            let oldIndex = oldChars.count - 1 - k
            let newIndex = newChars.count - 1 - k
            let oldLayer = oldIndex >= 0 ? slots[oldIndex] : nil

            if let oldLayer, newIndex >= 0, oldChars[oldIndex] == newChars[newIndex] {
                move(oldLayer, toX: xs[newIndex])
                newSlots[newIndex] = oldLayer
                continue
            }
            let begin = now + stagger
            if let oldLayer {
                rollOut(oldLayer, char: oldChars[oldIndex], offset: rising ? -travel : travel, begin: begin)
                outgoing.append(oldLayer)
            }
            if newIndex >= 0 {
                let incoming = makeLayer(for: newChars[newIndex], x: xs[newIndex])
                layer?.addSublayer(incoming)
                rollIn(incoming, char: newChars[newIndex], offset: rising ? travel : -travel, begin: begin)
                newSlots[newIndex] = incoming
            }
            stagger += 0.035
        }

        CATransaction.commit()
        slots = newSlots.compactMap { $0 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 + stagger) {
            outgoing.forEach { $0.removeFromSuperlayer() }
        }
    }

    private var laidOutHeight: CGFloat = 0

    override func layout() {
        super.layout()
        // Glyphs are placed from the leading edge, so only a height change moves them. Width
        // changes as digits come and go; rebuilding then would cut short a roll in progress.
        guard bounds.height != laidOutHeight else { return }
        laidOutHeight = bounds.height
        rebuildAll()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        rebuildAll()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        rebuildAll()
    }

    // MARK: Layers

    private var isDark: Bool {
        effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private var scale: CGFloat { window?.backingScaleFactor ?? 2 }

    private func glyph(_ char: Character) -> GlyphCache.Glyph {
        GlyphCache.glyph(char, size: size, dark: isDark, scale: scale)
    }

    private func rebuildAll() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        slots.forEach { $0.removeFromSuperlayer() }
        let chars = Array(text)
        let xs = offsets(for: chars)
        slots = chars.enumerated().map { makeLayer(for: $1, x: xs[$0]) }
        slots.forEach { layer?.addSublayer($0) }
        CATransaction.commit()
    }

    private func makeLayer(for char: Character, x: CGFloat) -> CALayer {
        let glyph = glyph(char)
        let layer = CALayer()
        layer.contents = glyph.sharp
        layer.contentsScale = scale
        let pad = GlyphCache.blurPadding
        let lineHeight = glyph.size.height - pad * 2
        layer.frame = CGRect(
            x: x - pad,
            y: (bounds.height - lineHeight) / 2 - pad,
            width: glyph.size.width,
            height: glyph.size.height
        )
        return layer
    }

    private func move(_ layer: CALayer, toX x: CGFloat) {
        let target = x - GlyphCache.blurPadding + layer.bounds.width / 2
        guard abs(layer.position.x - target) > 0.1 else { return }
        let slide = CASpringAnimation(keyPath: "position.x")
        slide.fromValue = layer.position.x
        slide.toValue = target
        slide.damping = 22
        slide.stiffness = 260
        slide.duration = slide.settlingDuration
        layer.position.x = target
        layer.add(slide, forKey: "slide")
    }

    private func rollIn(_ layer: CALayer, char: Character, offset: CGFloat, begin: CFTimeInterval) {
        let glyph = glyph(char)

        let rise = CASpringAnimation(keyPath: "transform")
        rise.fromValue = CATransform3DScale(CATransform3DMakeTranslation(0, offset, 0), 0.9, 0.9, 1)
        rise.toValue = CATransform3DIdentity
        rise.damping = 20
        rise.stiffness = 240
        rise.mass = 1
        rise.duration = rise.settlingDuration

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = 0.26
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let focus = CABasicAnimation(keyPath: "contents")
        focus.fromValue = glyph.blurred
        focus.toValue = glyph.sharp
        focus.duration = 0.32
        focus.timingFunction = CAMediaTimingFunction(name: .easeOut)

        for animation in [rise, fade, focus] as [CAAnimation] {
            animation.beginTime = begin + 0.06
            animation.fillMode = .backwards
            layer.add(animation, forKey: animation === rise ? "rise" : animation === fade ? "fade" : "focus")
        }
    }

    private func rollOut(_ layer: CALayer, char: Character, offset: CGFloat, begin: CFTimeInterval) {
        let glyph = glyph(char)
        let exit = CATransform3DScale(CATransform3DMakeTranslation(0, offset, 0), 0.9, 0.9, 1)

        let leave = CABasicAnimation(keyPath: "transform")
        leave.fromValue = CATransform3DIdentity
        leave.toValue = exit
        leave.duration = 0.2
        leave.timingFunction = CAMediaTimingFunction(name: .easeIn)

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = 0.16
        fade.timingFunction = CAMediaTimingFunction(name: .easeIn)

        let defocus = CABasicAnimation(keyPath: "contents")
        defocus.fromValue = glyph.sharp
        defocus.toValue = glyph.blurred
        defocus.duration = 0.14

        layer.transform = exit
        layer.opacity = 0
        layer.contents = glyph.blurred
        for animation in [leave, fade, defocus] as [CAAnimation] {
            animation.beginTime = begin
            animation.fillMode = .backwards
            layer.add(animation, forKey: nil)
        }
    }

    private func offsets(for chars: [Character]) -> [CGFloat] {
        var x: CGFloat = 0
        return chars.map { char in
            defer { x += glyph(char).advance }
            return x
        }
    }
}
