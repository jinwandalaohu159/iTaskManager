import AppKit
import QuartzCore
import SwiftUI

/// One shape drawn by `ShapeLayers`.
struct ShapeState {
    var id: String
    var path: CGPath
    var fill: Color?
    var stroke: Color?
    var lineWidth: CGFloat = 0
    var lineCap: CAShapeLayerLineCap = .butt
    var strokeStart: CGFloat = 0
    var strokeEnd: CGFloat = 1
}

/// Draws meters, rings and segments as Core Animation shape layers. When `token` changes
/// the paths and stroke ranges animate in the render server, so value changes cost the app
/// one update instead of a SwiftUI layout pass on every frame of the animation.
struct ShapeLayers: NSViewRepresentable {
    /// Changes whenever the data changes; a change animates, a resize doesn't.
    let token: AnyHashable
    let shapes: (CGSize) -> [ShapeState]

    func makeNSView(context: Context) -> ShapeLayersView {
        ShapeLayersView()
    }

    func updateNSView(_ view: ShapeLayersView, context: Context) {
        view.shapes = shapes
        view.update(token: token, animated: context.environment.smoothMotion && !context.transaction.disablesAnimations)
    }
}

final class ShapeLayersView: NSView {
    var shapes: (CGSize) -> [ShapeState] = { _ in [] }

    private var token: AnyHashable?
    private var layersByID: [String: CAShapeLayer] = [:]
    private var lastSize = CGSize.zero

    private static let duration: CFTimeInterval = 0.45
    private static let timing = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.25, 1)

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(token: AnyHashable, animated: Bool) {
        let changed = token != self.token
        let animate = animated && changed && self.token != nil && window != nil
        self.token = token
        apply(animated: animate)
    }

    override func layout() {
        super.layout()
        if bounds.size != lastSize {
            lastSize = bounds.size
            apply(animated: false)
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        apply(animated: false)
    }

    private func apply(animated: Bool) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let states = shapes(bounds.size)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let live = Set(states.map(\.id))
        for (id, layer) in layersByID where !live.contains(id) {
            layer.removeFromSuperlayer()
            layersByID[id] = nil
        }

        for (index, state) in states.enumerated() {
            let layer = layersByID[state.id] ?? {
                let layer = CAShapeLayer()
                self.layer?.addSublayer(layer)
                layersByID[state.id] = layer
                return layer
            }()
            layer.zPosition = CGFloat(index)
            layer.frame = bounds
            layer.fillColor = state.fill.map(resolved)
            layer.strokeColor = state.stroke.map(resolved)
            layer.lineWidth = state.lineWidth
            layer.lineCap = state.lineCap

            if animated {
                animate(layer, key: "path", from: layer.presentation()?.path ?? layer.path, to: state.path)
                animate(layer, key: "strokeStart", from: layer.presentation()?.strokeStart ?? layer.strokeStart, to: state.strokeStart)
                animate(layer, key: "strokeEnd", from: layer.presentation()?.strokeEnd ?? layer.strokeEnd, to: state.strokeEnd)
            }
            layer.path = state.path
            layer.strokeStart = state.strokeStart
            layer.strokeEnd = state.strokeEnd
        }

        CATransaction.commit()
    }

    private func animate(_ layer: CALayer, key: String, from: Any?, to: Any?) {
        guard let from else { return }
        let animation = CABasicAnimation(keyPath: key)
        animation.fromValue = from
        animation.toValue = to
        animation.duration = Self.duration
        animation.timingFunction = Self.timing
        layer.add(animation, forKey: key)
    }

    private func resolved(_ color: Color) -> CGColor {
        let nsColor = NSColor(color)
        var cgColor = nsColor.cgColor
        effectiveAppearance.performAsCurrentDrawingAppearance { cgColor = nsColor.cgColor }
        return cgColor
    }
}

/// Rounded rectangle path that never asks CoreGraphics for an impossible corner radius.
func roundedPath(_ rect: CGRect, radius: CGFloat) -> CGPath {
    let r = max(0, min(radius, rect.width / 2, rect.height / 2))
    return CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
}

/// A full circle starting at 12 o'clock and running clockwise (in a flipped view).
func ringPath(in size: CGSize, inset: CGFloat) -> CGPath {
    let radius = max(min(size.width, size.height) / 2 - inset, 0)
    let path = CGMutablePath()
    path.addArc(center: CGPoint(x: size.width / 2, y: size.height / 2), radius: radius,
                startAngle: -.pi / 2, endAngle: .pi * 1.5, clockwise: false)
    return path
}
