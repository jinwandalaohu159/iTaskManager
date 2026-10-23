import AppKit
import QuartzCore
import SwiftUI

/// Draws chart series with Core Animation. The path is rebuilt once per sample and the
/// glide between samples is a linear `position.x` animation that runs in the render
/// server, so a scrolling chart costs almost no CPU in the app itself.
struct ChartLayerView: NSViewRepresentable {
    let series: [ChartSeries]
    let maxValue: Double
    let lineWidth: CGFloat
    let dotSize: CGFloat
    let sampleDate: Date
    let interval: Double
    let smooth: Bool

    func makeNSView(context: Context) -> ChartNSView {
        ChartNSView()
    }

    func updateNSView(_ view: ChartNSView, context: Context) {
        view.update(
            series: series.map { .init(id: $0.id, color: NSColor($0.color), values: $0.values) },
            maxValue: maxValue,
            lineWidth: lineWidth,
            dotSize: dotSize,
            sampleDate: sampleDate,
            interval: interval,
            smooth: smooth
        )
    }
}

final class ChartNSView: NSView {
    /// How long the line takes to stretch to a new vertical scale. The axis labels use it too.
    static let rescaleDuration = 0.45

    struct Series {
        let id: String
        let color: NSColor
        let values: [Double]
    }

    private struct SeriesLayers {
        let fill: CAShapeLayer
        let gradient: CAGradientLayer
        let line: CAShapeLayer
        let dot: CAShapeLayer
    }

    private let clipLayer = CALayer()
    private let scrollLayer = CALayer()
    private var layersByID: [String: SeriesLayers] = [:]

    private var series: [Series] = []
    private var maxValue = 1.0
    private var lineWidth: CGFloat = 2
    private var dotSize: CGFloat = 8
    private var sampleDate = Date.distantPast
    private var interval = 1.0
    private var smooth = true
    private var lastSize = CGSize.zero
    private var hasDrawn = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false
        clipLayer.masksToBounds = true
        clipLayer.anchorPoint = .zero
        scrollLayer.anchorPoint = .zero
        clipLayer.addSublayer(scrollLayer)
        layer?.addSublayer(clipLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(series: [Series], maxValue: Double, lineWidth: CGFloat, dotSize: CGFloat,
                sampleDate: Date, interval: Double, smooth: Bool) {
        let isNewSample = sampleDate != self.sampleDate
        let previousMax = self.maxValue
        self.series = series
        self.maxValue = maxValue
        self.lineWidth = lineWidth
        self.dotSize = dotSize
        self.sampleDate = sampleDate
        self.interval = interval
        self.smooth = smooth
        let rescalesFrom = smooth && hasDrawn && previousMax != maxValue ? previousMax : nil
        rebuild(animate: isNewSample && smooth, rescalingFrom: rescalesFrom)
    }

    override func layout() {
        super.layout()
        if bounds.size != lastSize {
            lastSize = bounds.size
            rebuild(animate: false)
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        rebuild(animate: false)
    }

    // MARK: Drawing

    private var step: CGFloat { bounds.width / CGFloat(History.capacity - 1) }

    private func y(_ value: Double, scale: Double? = nil) -> CGFloat {
        ChartScale(maxValue: scale ?? maxValue, height: bounds.height, inset: lineWidth).y(value)
    }

    /// `rescalingFrom` is the previous ceiling when the vertical scale just changed: the line
    /// then morphs from the new data drawn at the old scale, so only heights move while the
    /// horizontal glide carries on.
    private func rebuild(animate: Bool, rescalingFrom oldScale: Double? = nil) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        hasDrawn = true
        let rescale = oldScale.map { scale in
            let morph = CABasicAnimation(keyPath: "path")
            morph.duration = min(Self.rescaleDuration, interval * 0.9)
            morph.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            return (scale: scale, animation: morph)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        clipLayer.frame = bounds
        scrollLayer.removeAllAnimations()
        scrollLayer.frame = CGRect(x: 0, y: 0, width: bounds.width + step, height: bounds.height)

        let liveIDs = Set(series.map(\.id))
        for (id, layers) in layersByID where !liveIDs.contains(id) {
            [layers.gradient, layers.line, layers.dot].forEach { $0.removeFromSuperlayer() }
            layersByID[id] = nil
        }

        let showsFill = series.count == 1
        for s in series {
            let layers = layersByID[s.id] ?? makeLayers(for: s.id)
            let color = resolved(s.color)
            let (line, area) = paths(for: s.values)
            if let rescale {
                let (oldLine, oldArea) = paths(for: s.values, scale: rescale.scale)
                for (layer, from, to) in [(layers.line, oldLine, line), (layers.fill, oldArea, area)] {
                    let morph = rescale.animation.copy() as! CABasicAnimation
                    morph.fromValue = from
                    morph.toValue = to
                    layer.add(morph, forKey: "rescale")
                }
            } else {
                layers.line.removeAnimation(forKey: "rescale")
                layers.fill.removeAnimation(forKey: "rescale")
            }

            layers.line.path = line
            layers.line.strokeColor = color
            layers.line.lineWidth = lineWidth

            layers.gradient.isHidden = !showsFill
            layers.gradient.frame = scrollLayer.bounds
            layers.fill.frame = scrollLayer.bounds
            layers.fill.path = area
            layers.gradient.colors = [resolved(s.color.withAlphaComponent(0.26)), resolved(s.color.withAlphaComponent(0.02))]

            layers.dot.path = CGPath(ellipseIn: CGRect(x: -dotSize / 2, y: -dotSize / 2, width: dotSize, height: dotSize), transform: nil)
            layers.dot.fillColor = color
            layers.dot.strokeColor = resolved(.windowBackgroundColor)
            layers.dot.lineWidth = 2
            layers.dot.isHidden = s.values.isEmpty

            let newest = s.values.last ?? 0
            let previous = s.values.count >= 2 ? s.values[s.values.count - 2] : newest
            layers.dot.position = CGPoint(x: bounds.width - 1, y: y(newest))
            layers.dot.removeAllAnimations()
            if animate {
                let move = CABasicAnimation(keyPath: "position.y")
                move.fromValue = y(previous)
                move.toValue = y(newest)
                move.duration = interval
                layers.dot.add(move, forKey: "glide")
            }
            if let rescale {
                // Rides on top of the glide, starting where the old scale left the dot.
                let shift = rescale.animation.copy() as! CABasicAnimation
                shift.keyPath = "position.y"
                shift.isAdditive = true
                shift.fromValue = y(previous, scale: rescale.scale) - y(previous)
                shift.toValue = 0
                layers.dot.add(shift, forKey: "rescale")
            }
        }

        // Final resting place: the newest point exactly on the right edge.
        scrollLayer.position = CGPoint(x: -step, y: 0)
        if animate {
            let elapsed = min(max(Date().timeIntervalSince(sampleDate) / interval, 0), 1)
            let slide = CABasicAnimation(keyPath: "position.x")
            slide.fromValue = -step * elapsed
            slide.toValue = -step
            slide.duration = interval * (1 - elapsed)
            scrollLayer.add(slide, forKey: "glide")
        }

        CATransaction.commit()
    }

    private func makeLayers(for id: String) -> SeriesLayers {
        let gradient = CAGradientLayer()
        gradient.anchorPoint = .zero
        let fill = CAShapeLayer()
        fill.anchorPoint = .zero
        fill.fillColor = NSColor.black.cgColor
        gradient.mask = fill

        let line = CAShapeLayer()
        line.fillColor = nil
        line.lineCap = .round
        line.lineJoin = .round

        let dot = CAShapeLayer()

        scrollLayer.addSublayer(gradient)
        scrollLayer.addSublayer(line)
        layer?.addSublayer(dot)
        let layers = SeriesLayers(fill: fill, gradient: gradient, line: line, dot: dot)
        layersByID[id] = layers
        return layers
    }

    /// Smoothed line through the samples with the newest point one step past the right edge.
    private func paths(for values: [Double], scale: Double? = nil) -> (CGPath, CGPath) {
        let line = CGMutablePath()
        let area = CGMutablePath()
        guard values.count >= 2 else { return (line, area) }

        let width = bounds.width + step
        let points = values.enumerated().map { index, value in
            CGPoint(x: width - CGFloat(values.count - 1 - index) * step, y: y(value, scale: scale))
        }
        line.move(to: points[0])
        for i in 1..<points.count {
            let mid = CGPoint(x: (points[i - 1].x + points[i].x) / 2, y: (points[i - 1].y + points[i].y) / 2)
            line.addQuadCurve(to: mid, control: points[i - 1])
        }
        line.addLine(to: points[points.count - 1])

        area.addPath(line)
        area.addLine(to: CGPoint(x: points[points.count - 1].x, y: bounds.height))
        area.addLine(to: CGPoint(x: points[0].x, y: bounds.height))
        area.closeSubpath()
        return (line, area)
    }

    private func resolved(_ color: NSColor) -> CGColor {
        var cg = color.cgColor
        effectiveAppearance.performAsCurrentDrawingAppearance { cg = color.cgColor }
        return cg
    }
}
