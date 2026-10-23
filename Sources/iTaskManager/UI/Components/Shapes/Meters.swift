import SwiftUI

/// Horizontal capsule meter.
struct UsageBar: View {
    let value: Double
    let color: Color
    var height: CGFloat = 6

    var body: some View {
        let v = min(max(value, 0), 1)
        ShapeLayers(token: v) { size in
            let width = v > 0.004 ? max(size.height, size.width * v) : 0
            return [
                ShapeState(id: "track", path: roundedPath(CGRect(origin: .zero, size: size), radius: size.height / 2),
                           fill: color.opacity(0.18)),
                ShapeState(id: "fill", path: roundedPath(CGRect(x: 0, y: 0, width: width, height: size.height), radius: size.height / 2),
                           fill: color),
            ]
        }
        .frame(height: height)
    }
}

/// Vertical meter for a single CPU core.
struct CoreMeter: View {
    let value: Double
    let color: Color
    var width: CGFloat = 8

    var body: some View {
        let v = min(max(value, 0), 1)
        ShapeLayers(token: v) { size in
            let radius = min(size.width / 2, 4)
            let height = v > 0.004 ? max(3, size.height * v) : 0
            return [
                ShapeState(id: "track", path: roundedPath(CGRect(origin: .zero, size: size), radius: radius),
                           fill: color.opacity(0.16)),
                ShapeState(id: "fill", path: roundedPath(CGRect(x: 0, y: size.height - height, width: size.width, height: height), radius: radius),
                           fill: color),
            ]
        }
        .frame(width: width)
    }
}

struct Segment: Identifiable {
    let id: String
    let color: Color
    let value: Double
}

/// Part-to-whole bar: segments separated by a 2pt gap over a neutral track.
struct SegmentedBar: View {
    let segments: [Segment]
    let total: Double
    var height: CGFloat = 12

    var body: some View {
        // Readings come from different sensors and can sum past `total`; never overflow the track.
        let whole = max(total, segments.reduce(0) { $0 + max($1.value, 0) })
        ShapeLayers(token: segments.map(\.value) + [whole]) { size in
            let radius = size.height / 2.5
            let visible = segments.filter { $0.value > 0 }
            let gaps = CGFloat(max(visible.count - 1, 0)) * 2
            let usable = max(size.width - gaps, 0)
            var shapes = [ShapeState(id: "track", path: roundedPath(CGRect(origin: .zero, size: size), radius: radius),
                                     fill: Color.primary.opacity(0.07))]
            var x: CGFloat = 0
            for segment in segments {
                let width = whole > 0 && segment.value > 0 ? usable * segment.value / whole : 0
                shapes.append(ShapeState(
                    id: segment.id,
                    path: roundedPath(CGRect(x: x, y: 0, width: width, height: size.height), radius: min(3, radius)),
                    fill: segment.color
                ))
                if width > 0 { x += width + 2 }
            }
            return shapes
        }
        .frame(height: height)
    }
}
