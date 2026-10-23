import SwiftUI

struct ChartSeries: Identifiable {
    let id: String
    let color: Color
    let values: [Double]
}

/// A history chart that glides continuously instead of jumping once per sample.
/// Drawing and the glide are done by `ChartLayerView`; this adds the grid, axis and hover.
struct LiveChart: View {
    enum Style {
        case sparkline
        case full
    }

    let series: [ChartSeries]
    var maxValue: Double = 1
    var style: Style = .sparkline
    var format: (Double) -> String = Fmt.percent
    /// Axis ticks; defaults to `format`.
    var axisFormat: ((Double) -> String)? = nil

    @Environment(SystemMonitor.self) private var monitor
    @Environment(\.smoothMotion) private var smooth
    @State private var hoverX: CGFloat?

    private var axisWidth: CGFloat { style == .full ? 44 : 0 }
    private var lineWidth: CGFloat { style == .full ? 2 : 1.5 }
    private var dotSize: CGFloat { style == .full ? 8 : 6 }

    var body: some View {
        GeometryReader { geo in
            let plot = CGSize(width: max(geo.size.width - axisWidth, 1), height: geo.size.height)
            HStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    if style == .full { gridLines(plot) } else { baseline(plot) }
                    ChartLayerView(
                        series: series,
                        maxValue: maxValue,
                        lineWidth: lineWidth,
                        dotSize: dotSize,
                        sampleDate: monitor.lastSampleDate,
                        interval: monitor.interval,
                        smooth: smooth
                    )
                    if style == .full, let hoverX {
                        ChartHoverOverlay(
                            series: series, scale: scale(plot), size: plot, x: hoverX,
                            progress: progress(at: .now), interval: monitor.interval, format: format
                        )
                    }
                }
                .frame(width: plot.width, height: plot.height)
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    guard style == .full else { return }
                    switch phase {
                    case .active(let point): hoverX = point.x
                    case .ended: hoverX = nil
                    }
                }
                if style == .full { axisLabels(plot) }
            }
        }
    }

    // MARK: Geometry

    private func progress(at date: Date) -> Double {
        guard smooth else { return 1 }
        let elapsed = date.timeIntervalSince(monitor.lastSampleDate)
        return min(max(elapsed / max(monitor.interval, 0.1), 0), 1)
    }

    private func scale(_ size: CGSize) -> ChartScale {
        ChartScale(maxValue: maxValue, height: size.height, inset: lineWidth)
    }

    private func y(_ value: Double, _ size: CGSize) -> CGFloat {
        scale(size).y(value)
    }

    // MARK: Layers

    private func gridLines(_ size: CGSize) -> some View {
        ChartGrid(size: size, inset: lineWidth).equatable()
    }

    private func baseline(_ size: CGSize) -> some View {
        Rectangle()
            .fill(Color.primary.opacity(0.1))
            .frame(width: size.width, height: 1)
            .offset(y: size.height - 1)
    }

    /// Ticks are keyed by value, so when the scale changes a tick both scales share (20 W going
    /// from 0–20 to 0–40) slides to its new place and the rest cross-fade, in step with the
    /// line rescaling in `ChartNSView`.
    private func axisLabels(_ size: CGSize) -> some View {
        let label = axisFormat ?? format
        return ZStack(alignment: .topLeading) {
            ForEach([0, maxValue / 2, maxValue], id: \.self) { value in
                Text(label(value))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                    .fixedSize()
                    .position(x: axisWidth / 2 + 4, y: y(value, size))
                    .transition(.opacity)
            }
        }
        .frame(width: axisWidth, height: size.height)
        .animation(smooth ? .easeInOut(duration: ChartNSView.rescaleDuration) : nil, value: maxValue)
    }
}
