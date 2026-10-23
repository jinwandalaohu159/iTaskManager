import SwiftUI

struct Ring: Identifiable {
    let id: String
    let value: Double
    let color: Color
}

/// Concentric activity rings, outermost first.
struct RingGauge<Center: View>: View {
    let rings: [Ring]
    var lineWidth: CGFloat = 14
    var gap: CGFloat = 4
    @ViewBuilder var center: Center

    var body: some View {
        ZStack {
            ShapeLayers(token: rings.map(\.value)) { size in
                rings.enumerated().flatMap { index, ring -> [ShapeState] in
                    let path = ringPath(in: size, inset: CGFloat(index) * (lineWidth + gap) + lineWidth / 2)
                    return [
                        ShapeState(id: "\(ring.id)-track", path: path, stroke: ring.color.opacity(0.16), lineWidth: lineWidth),
                        ShapeState(id: ring.id, path: path, stroke: ring.color, lineWidth: lineWidth, lineCap: .round,
                                   strokeEnd: min(max(ring.value, 0.004), 1)),
                    ]
                }
            }
            center
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Part-to-whole ring. Segments are separated by small gaps; the remainder shows as track.
struct DonutChart<Center: View>: View {
    let segments: [Segment]
    let total: Double
    var lineWidth: CGFloat = 16
    @ViewBuilder var center: Center

    var body: some View {
        let whole = max(total, segments.reduce(0) { $0 + max($1.value, 0) })
        ZStack {
            ShapeLayers(token: segments.map(\.value) + [whole]) { size in
                let path = ringPath(in: size, inset: lineWidth / 2)
                var shapes = [ShapeState(id: "track", path: path, stroke: Color.primary.opacity(0.07), lineWidth: lineWidth)]
                let gap = 0.008
                var cursor = 0.0
                for segment in segments {
                    let fraction = whole > 0 ? max(min(segment.value / whole, 1 - cursor), 0) : 0
                    let start = cursor + gap / 2
                    let end = fraction > gap ? cursor + fraction - gap / 2 : start
                    shapes.append(ShapeState(id: segment.id, path: path, stroke: segment.color, lineWidth: lineWidth,
                                             strokeStart: start, strokeEnd: end))
                    cursor += fraction
                }
                return shapes
            }
            center.padding(lineWidth)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
