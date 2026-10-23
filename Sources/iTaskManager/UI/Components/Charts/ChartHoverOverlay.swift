import SwiftUI

/// The crosshair, point markers and tooltip shown while hovering a full-size chart. It follows
/// the chart's glide, so it snaps to the sample under the pointer as the line scrolls.
struct ChartHoverOverlay: View {
    let series: [ChartSeries]
    let scale: ChartScale
    let size: CGSize
    let x: CGFloat
    /// How far the current glide has progressed, 0...1.
    let progress: Double
    let interval: Double
    let format: (Double) -> String

    var body: some View {
        let p = progress
        let count = series.map(\.values.count).max() ?? 0
        let s = size.width / CGFloat(History.capacity - 1)
        // Screen x of the newest point is width + s * (1 - p).
        let stepsBack = Int(((size.width + s * (1 - p)) - x) / s + 0.5)
        let index = count - 1 - max(stepsBack, 0)
        let pointX = size.width + s * (1 - p) - CGFloat(count - 1 - index) * s

        return ZStack(alignment: .topLeading) {
            if index >= 0 && index < count && pointX >= 0 && pointX <= size.width {
                Rectangle()
                    .fill(Color.primary.opacity(0.25))
                    .frame(width: 1, height: size.height)
                    .position(x: pointX, y: size.height / 2)
                ForEach(series) { series in
                    if index < series.values.count {
                        Circle()
                            .fill(series.color)
                            .frame(width: 8, height: 8)
                            .background(Circle().fill(Color(nsColor: .windowBackgroundColor)).padding(-2))
                            .position(x: pointX, y: scale.y(series.values[index]))
                    }
                }
                tooltip(index: index, count: count)
                    .fixedSize()
                    .alignmentGuide(.leading) { d in
                        let preferred = pointX + 12
                        return -(preferred + d.width > size.width ? pointX - d.width - 12 : preferred)
                    }
                    .alignmentGuide(.top) { _ in -4 }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func tooltip(index: Int, count: Int) -> some View {
        let secondsAgo = Int((Double(count - 1 - index) * interval).rounded())
        return VStack(alignment: .leading, spacing: 4) {
            Text(secondsAgo == 0 ? L("现在") : L("\(secondsAgo) 秒前"))
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(series) { s in
                if index < s.values.count {
                    HStack(spacing: 6) {
                        Circle().fill(s.color).frame(width: 7, height: 7)
                        Text(format(s.values[index])).font(.callout.weight(.medium)).monospacedDigit()
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }
}
