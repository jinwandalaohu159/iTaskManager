import SwiftUI

/// The detail pages' lead card: a gauge with its legend on the left, a titled history chart
/// on the right.
struct GaugeChartCard<Gauge: View, Legend: View, Facts: View, Chart: View>: View {
    let title: String
    var chartHeight: CGFloat = 230
    @ViewBuilder var gauge: Gauge
    @ViewBuilder var legend: Legend
    @ViewBuilder var facts: Facts
    @ViewBuilder var chart: Chart

    var body: some View {
        Card(padding: 20) {
            HStack(alignment: .center, spacing: 32) {
                VStack(spacing: 16) {
                    gauge.frame(width: 168, height: 168)
                    VStack(spacing: 6) { legend }
                        .frame(width: 210)
                }
                VStack(alignment: .leading, spacing: 12) {
                    // Stats sit beside the title when there's room, under it otherwise.
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(title).font(.headline)
                            Spacer(minLength: 16)
                            facts
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(title).font(.headline)
                            facts
                        }
                    }
                    chart
                }
                .frame(height: chartHeight)
            }
        }
    }
}

/// The number in the middle of a gauge.
struct GaugeCenter: View {
    let text: String
    let value: Double
    let caption: String

    var body: some View {
        VStack(spacing: 0) {
            LiveNumber(text: text, value: value, size: 30)
            Text(caption).font(.caption.weight(.medium)).foregroundStyle(.secondary)
        }
    }
}
